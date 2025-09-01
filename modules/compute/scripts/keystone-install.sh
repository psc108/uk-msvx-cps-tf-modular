set -euo pipefail
%{ if debug }set -x%{ endif }
if [ -f /opt/scripts/.setup-done ]; then
  # Create keystone configuration file
  cat > /etc/keystone/keystone.conf << EOF
[DEFAULT]

[database]
connection = mysql+pymysql://keystone:${keystone_password}@${mysql_hostname}/keystone

[token]
provider = fernet
EOF
  chown keystone:keystone /etc/keystone/keystone.conf
  if [ ${count_index} -eq 0 ]; then
    su -s /bin/sh -c 'keystone-manage db_sync' keystone
  fi
  keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
  keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
  
  # Ensure WSGI script exists
  if [ ! -f /usr/local/bin/keystone-wsgi-public ]; then
    cat > /usr/local/bin/keystone-wsgi-public << 'WSGI_EOF'
#!/usr/bin/env python3
import sys
from keystone.server.wsgi import initialize_application
application = initialize_application('public')
WSGI_EOF
    chmod +x /usr/local/bin/keystone-wsgi-public
  fi
  
  # Create WSGI configuration for Apache
  cat > /etc/httpd/conf.d/wsgi-keystone.conf << 'EOF'
Listen 5000

<VirtualHost *:5000>
    WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-public
    WSGIScriptAlias /api/idm /usr/local/bin/keystone-wsgi-public
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    LimitRequestBody 114688
    <IfVersion ">= 2.4">
      ErrorLogFormat "%{cu}t %M"
    </IfVersion>
    ErrorLog /var/log/httpd/keystone.log
    CustomLog /var/log/httpd/keystone_access.log combined
    
    SSLEngine on
    SSLCertificateFile /etc/keystone/server.crt
    SSLCertificateKeyFile /etc/keystone/server.key
    SSLCACertificateFile /etc/keystone/ca.crt
    
    <Directory /usr/local/bin>
        <IfVersion ">= 2.4">
            Require all granted
        </IfVersion>
        <IfVersion "< 2.4">
            Order allow,deny
            Allow from all
        </IfVersion>
    </Directory>
</VirtualHost>
SSLPassPhraseDialog exec:/etc/keystone/server.key.password.sh
EOF
  
  sed -i '/#ServerName/a ServerName keystone0${count_index + 1}.${private_zone_name}' /etc/httpd/conf/httpd.conf
  
  # Install guide step 3
  cd /opt/scripts/ssl/keystone0${count_index + 1}
  cp server.key server.crt ../ca/ca.crt /etc/keystone
  chown keystone:keystone /etc/keystone/server.key /etc/keystone/server.crt /etc/keystone/ca.crt
  
  keystone-manage bootstrap --bootstrap-password ${keystone_password} --bootstrap-admin-url https://keystone0${count_index + 1}.${private_zone_name}:5000/api/idm/v3/ --bootstrap-internal-url https://keystone0${count_index + 1}.${private_zone_name}:5000/api/idm/v3/ --bootstrap-public-url https://keystone0${count_index + 1}.${private_zone_name}:5000/api/idm/v3/ --bootstrap-region-id RegionOne
  
  # Install guide step 4
  setsebool -P httpd_read_user_content 1 || true  # May not be available on Amazon Linux
  systemctl enable --now httpd.service
  source /home/ecs/env.sh
  
  # Install guide step 5 - Find Python site-packages directory
  PYTHON_SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])")
  if [ -d "$PYTHON_SITE_PACKAGES/keystone/common" ]; then
    cp /opt/scripts/idm/patch/render_token.py $PYTHON_SITE_PACKAGES/keystone/common/render_token.py
    rm -f $PYTHON_SITE_PACKAGES/keystone/common/__pycache__/render_token.*
  else
    echo "Warning: Keystone Python package directory not found at $PYTHON_SITE_PACKAGES/keystone/common"
  fi
  cp /opt/scripts/idm/policy.json /etc/keystone/policy.json
  
  if [ ${count_index} -eq 0 ]; then
    # Install guide step 6
    cd /opt/scripts/idm
    chown ecs *.sh
    ./create_roles.sh
    ./create_system_domain.sh
    # Flag backend/frontend installs to proceed
    touch /opt/scripts/.keystone-done
  fi
fi