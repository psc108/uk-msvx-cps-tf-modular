set -euo pipefail
%{ if debug }set -x%{ endif }
if [ -f /opt/scripts/.keystone-done ]; then
  setsebool -P httpd_can_network_connect 1 || true  # May not be available on Amazon Linux
  systemctl enable --now nginx
  dnf install nodejs -y
  unzip /opt/scripts/installation-package.jar -d /opt/install
  cp /opt/scripts/ssp/setup.properties /opt/install
  cd /opt/scripts/ssl/frontend0${count_index + 1}
  mkdir -p /opt/ecs/security
  cp server.key server.crt ../ca/ca.crt /opt/ecs/security 2>/dev/null || true
  cp server.keystore server.truststore /opt/ecs/security 2>/dev/null || true
  cd /opt/install
  su -c 'python3 installer.py -i frontend,frontend-lb,doc > install.log'
fi