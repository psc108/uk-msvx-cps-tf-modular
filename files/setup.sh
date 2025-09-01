#!/bin/bash
set -euo pipefail

# Setup script for CSO Shared Services Portal on Amazon Linux 2023
# This script runs on the jump server and prepares the environment

echo "Starting CSO setup on Amazon Linux 2023..."

# Download all files from S3 to EFS
echo "Downloading all files from S3..."
aws s3 sync s3://${S3_BUCKET}/ /opt/scripts/ --exclude "scripts/*" || {
    echo "Failed to download files from S3"
    exit 1
}

# Debug: Show what files were downloaded
echo "Files downloaded to /opt/scripts/:"
ls -la /opt/scripts/

# Download setup scripts to /tmp for execution
aws s3 sync s3://${S3_BUCKET}/scripts/ /tmp/ || {
    echo "Failed to download setup scripts from S3"
}

# Extract and prepare installation scripts
if [ -f /opt/scripts/manual-installation-scripts.tar.gz ]; then
    tar -xzf /opt/scripts/manual-installation-scripts.tar.gz -C /opt/scripts/

    # Fix any CentOS-specific commands in extracted scripts
    find /opt/scripts -name "*.sh" -type f -exec sed -i 's/yum /dnf /g' {} \; 2>/dev/null || true
    find /opt/scripts -name "*.sh" -type f -exec sed -i 's/python2/python3/g' {} \; 2>/dev/null || true

    echo "Installation scripts extracted and patched for Amazon Linux 2023"
fi

# Generate SSL certificates
echo "Generating SSL certificates..."

# Create CA directory structure
mkdir -p /opt/scripts/ssl/ca
cd /opt/scripts/ssl

# Generate Root CA
openssl genrsa -out ca/ca.key 4096
openssl req -new -x509 -days 3650 -key ca/ca.key -out ca/ca.crt -subj "/C=US/ST=State/L=City/O=Organization/CN=CSO-CA"

# Generate certificates for each service
for host in frontend01 frontend02 backend01 backend02 keystone01 keystone02 rabbitmq01 rabbitmq02; do
  mkdir -p $host
  cd $host

  # Generate private key
  openssl genrsa -out server.key 2048

  # Create certificate signing request
  openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=City/O=Organization/CN=$host.dev-ha.cso.internal"

  # Generate certificate
  openssl x509 -req -in server.csr -CA ../ca/ca.crt -CAkey ../ca/ca.key -CAcreateserial -out server.crt -days 365

  # Create unencrypted key for services that need it
  cp server.key server.key.nopass

  # Create Java keystore and truststore
  echo "changeit" > server.key.password
  openssl pkcs12 -export -in server.crt -inkey server.key -out server.p12 -password pass:changeit
  keytool -importkeystore -srckeystore server.p12 -srcstoretype PKCS12 -destkeystore server.keystore -deststoretype JKS -srcstorepass changeit -deststorepass changeit -noprompt
  keytool -import -alias ca -file ../ca/ca.crt -keystore server.truststore -storepass changeit -noprompt

  cd ..
done

echo "SSL certificates generated successfully"

# Create database setup scripts directory
mkdir -p /opt/scripts/database

# Create keystone database setup
cat > /opt/scripts/database/create_keystone_db.sql << 'EOF'
CREATE DATABASE IF NOT EXISTS keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'keystonepass';
FLUSH PRIVILEGES;
EOF

# Create SSP database users script
cat > /opt/scripts/database/create_ssp_users.sql << 'EOF'
-- CSO SSP Database Users
CREATE USER IF NOT EXISTS 'ssp_user'@'%' IDENTIFIED BY 'servicepass';
GRANT SELECT, INSERT, UPDATE, DELETE ON *.* TO 'ssp_user'@'%';
FLUSH PRIVILEGES;
EOF

# Create RabbitMQ setup scripts
mkdir -p /opt/scripts/rabbit

cat > /opt/scripts/rabbit/create_users.sh << 'EOF'
#!/bin/bash
# Create RabbitMQ users for CSO
rabbitmqctl add_user ssp_user $1
rabbitmqctl set_permissions -p /ssp ssp_user ".*" ".*" ".*"
EOF
chmod +x /opt/scripts/rabbit/create_users.sh

cat > /opt/scripts/rabbit/create_vhost.sh << 'EOF'
#!/bin/bash
# Create RabbitMQ vhost for CSO
rabbitmqctl add_vhost $1
EOF
chmod +x /opt/scripts/rabbit/create_vhost.sh

# Create IDM setup scripts directory
mkdir -p /opt/scripts/idm

# Create basic OpenStack role creation script
cat > /opt/scripts/idm/create_roles.sh << 'EOF'
#!/bin/bash
# Create OpenStack roles for CSO
source /home/ecs/env.sh
openstack role create --or-show admin
openstack role create --or-show member
openstack role create --or-show reader
EOF
chmod +x /opt/scripts/idm/create_roles.sh

# Create system domain script
cat > /opt/scripts/idm/create_system_domain.sh << 'EOF'
#!/bin/bash
# Create system domain for CSO
source /home/ecs/env.sh
openstack domain create --or-show --description "System Domain" system
EOF
chmod +x /opt/scripts/idm/create_system_domain.sh

# Create patch directory and basic render_token.py
mkdir -p /opt/scripts/idm/patch
cat > /opt/scripts/idm/patch/render_token.py << 'EOF'
# Basic render_token.py patch for CSO compatibility
import json

def render_token(token_data):
    """Render token data for CSO compatibility"""
    return json.dumps(token_data)
EOF

# Create basic policy.json
cat > /opt/scripts/idm/policy.json << 'EOF'
{
    "admin_required": "role:admin",
    "service_role": "role:service",
    "service_or_admin": "rule:admin_required or rule:service_role",
    "owner": "user_id:%(user_id)s",
    "admin_or_owner": "rule:admin_required or rule:owner",
    "identity:get_user": "rule:admin_or_owner",
    "identity:list_users": "rule:admin_required",
    "identity:create_user": "rule:admin_required",
    "identity:update_user": "rule:admin_required",
    "identity:delete_user": "rule:admin_required"
}
EOF

# Create SSP setup directory
mkdir -p /opt/scripts/ssp

# Create setup.properties from quickSetup.properties or downloaded file
if [ -f /opt/scripts/quickSetup.properties ]; then
    cp /opt/scripts/quickSetup.properties /opt/scripts/ssp/setup.properties
    echo "Setup properties created from downloaded quickSetup.properties"
elif [ -f /home/ecs/quickSetup.properties ]; then
    cp /home/ecs/quickSetup.properties /opt/scripts/ssp/setup.properties
    echo "Setup properties created from /home/ecs/quickSetup.properties"
else
    # Create basic setup.properties with default values
    cat > /opt/scripts/ssp/setup.properties << 'EOF'
mysql-hostname=localhost
keystone-password=keystonepass
service-password=servicepass
rabbitmq-password=rabbitpass
keystore-password=changeit
EOF
    echo "Created basic setup.properties with defaults"
fi

# Verify setup.properties was created
if [ -f /opt/scripts/ssp/setup.properties ]; then
    echo "✓ setup.properties created successfully"
    echo "Contents:"
    cat /opt/scripts/ssp/setup.properties
else
    echo "✗ Failed to create setup.properties"
fi

# Create /opt/install directory on EFS for CSO installation (shared across all servers)
mkdir -p /opt/scripts/install

# Copy setup.properties to EFS install directory for keystone-setup.sh
if [ -f /opt/scripts/ssp/setup.properties ]; then
    cp /opt/scripts/ssp/setup.properties /opt/scripts/install/setup.properties
    echo "Copied setup.properties to /opt/scripts/install/"
fi

# Extract installation package to EFS install directory if available
if [ -f /opt/scripts/installation-package-*.jar ]; then
    cp /opt/scripts/installation-package-*.jar /opt/scripts/install/
    echo "Copied installation package to /opt/scripts/install/"
else
    echo "Warning: Installation package not found in /opt/scripts/"
    ls -la /opt/scripts/installation-package* 2>/dev/null || echo "No installation package files found"
fi

# Create local symlink to EFS install directory for compatibility
ln -sf /opt/scripts/install /opt/install
echo "Created symlink /opt/install -> /opt/scripts/install"

# Mark setup as complete
touch /opt/scripts/.setup-done

echo "CSO setup completed successfully on Amazon Linux 2023"
echo "Created directories: /opt/scripts/ssp, /opt/install"
echo "Created files: setup.properties, SSL certificates, database scripts"