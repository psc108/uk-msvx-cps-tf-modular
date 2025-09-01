#!/bin/bash
# CSO Security Hardening Script

set -euo pipefail

# Disable unnecessary services
systemctl disable --now avahi-daemon 2>/dev/null || true
systemctl disable --now cups 2>/dev/null || true
systemctl disable --now bluetooth 2>/dev/null || true

# Configure SSH hardening
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 300/' /etc/ssh/sshd_config
sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 2/' /etc/ssh/sshd_config

# Restart SSH service
systemctl restart sshd

# Configure firewall (allow only necessary ports)
dnf install -y firewalld
systemctl enable --now firewalld

# Default deny all
firewall-cmd --set-default-zone=drop
firewall-cmd --zone=drop --add-interface=eth0 --permanent

# Allow SSH from jump server only (will be configured by security groups)
firewall-cmd --zone=drop --add-service=ssh --permanent

# Allow application ports (will be restricted by security groups)
firewall-cmd --zone=drop --add-port=8102/tcp --permanent  # Frontend
firewall-cmd --zone=drop --add-port=5000/tcp --permanent   # Keystone
firewall-cmd --zone=drop --add-port=5671/tcp --permanent   # RabbitMQ SSL
firewall-cmd --zone=drop --add-port=15671/tcp --permanent  # RabbitMQ Management SSL
firewall-cmd --zone=drop --add-port=3306/tcp --permanent   # MySQL
firewall-cmd --zone=drop --add-port=2049/tcp --permanent   # NFS

firewall-cmd --reload

# Configure fail2ban for additional protection
dnf install -y fail2ban
systemctl enable --now fail2ban

# Create fail2ban SSH jail
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/secure
maxretry = 3
bantime = 3600
EOF

systemctl restart fail2ban

# Set up log rotation for security logs
cat > /etc/logrotate.d/security << 'EOF'
/var/log/secure {
    weekly
    rotate 52
    compress
    delaycompress
    missingok
    notifempty
    create 600 root root
}
EOF

# Configure kernel parameters for security
cat >> /etc/sysctl.conf << 'EOF'
# Network security
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.ip_forward = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
EOF

sysctl -p

echo "Security hardening completed successfully"