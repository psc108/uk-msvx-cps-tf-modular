#!/bin/bash
# File preparation user data script

set -e

echo "[FILE-PREP] Starting file preparation process..."

# Install required packages
dnf update -y
dnf install -y nfs-utils aws-cli unzip tar gzip

# Create mount point
mkdir -p /opt/scripts

# Mount EFS
echo "[FILE-PREP] Mounting EFS: ${efs_dns_name}"
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,intr,timeo=600,retrans=2 ${efs_dns_name}:/ /opt/scripts

# Create directory structure
mkdir -p /opt/scripts/{install,ssl,database,rabbit,idm,ssp}

# Download all files from S3
echo "[FILE-PREP] Downloading files from S3 bucket: ${s3_bucket}"
aws s3 sync s3://${s3_bucket} /opt/scripts/ --exclude "*.tfstate*"

# Extract installation package if present
if ls /opt/scripts/installation-package*.jar >/dev/null 2>&1; then
    echo "[FILE-PREP] Extracting installation package..."
    cd /opt/scripts/install
    unzip -q /opt/scripts/installation-package*.jar || echo "Package extraction completed with warnings"
    
    # Patch extracted scripts for Amazon Linux 2023
    find . -name "*.sh" -exec sed -i 's/yum /dnf /g' {} \;
    find . -name "*.sh" -exec sed -i 's/python /python3 /g' {} \;
    find . -name "*.py" -exec sed -i '1s|#!/usr/bin/python|#!/usr/bin/python3|' {} \;
fi

# Extract keystone virtual environment if present
if [ -f /opt/scripts/keystone-antelope-venv.tar.gz ]; then
    echo "[FILE-PREP] Extracting keystone virtual environment..."
    cd /opt/scripts
    tar -xzf keystone-antelope-venv.tar.gz
fi

# Set permissions
chmod -R 755 /opt/scripts
find /opt/scripts -name "*.sh" -exec chmod +x {} \;

# Create completion flag
echo "[FILE-PREP] File preparation completed at $(date)" > /opt/scripts/.file-prep-complete
echo "Environment: ${environment}" >> /opt/scripts/.file-prep-complete
echo "S3 Bucket: ${s3_bucket}" >> /opt/scripts/.file-prep-complete
echo "EFS DNS: ${efs_dns_name}" >> /opt/scripts/.file-prep-complete

echo "[FILE-PREP] File preparation process completed successfully"

# Signal completion and shutdown
/opt/aws/bin/cfn-signal -e $? --stack ${environment}-file-prep --resource FilePrep --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region) || true

# Shutdown instance after completion
shutdown -h +2 "File preparation complete, shutting down in 2 minutes"