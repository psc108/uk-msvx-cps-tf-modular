##### Compute Module - EC2 Instances #####

data "aws_region" "current" {}

##### Jump Server #####
resource "aws_instance" "jump-server" {
  ami                         = var.ami_id
  instance_type               = "t2.large"
  subnet_id                   = var.public_subnets[0].id
  associate_public_ip_address = true
  iam_instance_profile        = var.ssm_instance_profile.name
  monitoring                  = true

  vpc_security_group_ids = [
    var.security_groups.jump_server.id,
    var.security_groups.external_web_access.id,
    var.security_groups.efs.id
  ]

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    iops                  = 3000
    volume_size           = 50
    volume_type           = "gp3"
  }

  tags = {
    Name        = "${var.environment}-jump-server"
    Environment = var.environment
    PatchGroup  = "${var.environment}-cso-instances"
    Backup      = "required"
    Monitoring  = "enabled"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    exec > /var/log/cloud-init-output.log 2>&1
    
    echo "Jump server cloud-init started at $(date)"
    
    # Basic package installation
    dnf update -y
    dnf install -y awscli amazon-ssm-agent nfs-utils
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    
    # Mount EFS first
    mkdir -p /opt/scripts
    echo "Attempting to mount EFS: ${var.efs_dns_name}"
    if mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 ${var.efs_dns_name}:/ /opt/scripts; then
      echo "EFS mounted successfully"
      echo '${var.efs_dns_name}:/ /opt/scripts nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 0 0' >> /etc/fstab
      
      # Create /opt/install symlink immediately after EFS mount
      echo "Creating /opt/install symlink immediately after EFS mount"
      mkdir -p /opt/scripts/install
      rm -rf /opt/install 2>/dev/null || true
      ln -sf /opt/scripts/install /opt/install
      echo "Symlink created: /opt/install -> $(readlink /opt/install)"
      ls -la /opt/install/
    else
      echo "EFS mount failed - will retry in setup script"
    fi
    
    # Run embedded setup script
    echo "Running embedded jump server setup..."
    
    # Wait for S3 files to be uploaded first
    echo "Waiting for S3 files to be available..."
    timeout 10m sh -c 'while ! aws s3 ls s3://${var.user_data_base.s3_bucket}/jump-server-setup.sh >/dev/null 2>&1; do echo "Waiting for S3 files..."; sleep 30; done' || echo "S3 files not ready, proceeding anyway"
    
    # Download and run the setup script
    if aws s3 cp s3://${var.user_data_base.s3_bucket}/jump-server-setup.sh /tmp/ 2>/dev/null; then
      chmod +x /tmp/jump-server-setup.sh
      /tmp/jump-server-setup.sh "${var.efs_dns_name}" "${var.user_data_base.s3_bucket}" "${var.environment}"
    else
      echo "Could not download setup script from S3, running basic setup..."
      
      # Basic setup if S3 script not available
      cd /opt/scripts
      
      # Download files from S3 if available
      aws s3 sync s3://${var.user_data_base.s3_bucket}/ ./ --exclude "*.tfstate*" || echo "S3 sync failed"
      
      # Create basic structure
      mkdir -p ssl/ca database ssp install
      
      # Create completion flag
      touch .setup-complete
      echo "Basic jump server setup completed at $(date)"
    fi
    
    echo "Jump server cloud-init completed at $(date)"
  EOF
  )

  depends_on = [var.efs_mount_targets]
}

##### Frontend Servers #####
resource "aws_instance" "frontend" {
  count         = var.ha ? 2 : 1
  ami           = var.ami_id
  instance_type = var.prod ? "c5.2xlarge" : "t2.xlarge"
  subnet_id     = var.ha ? var.private_subnets[count.index % length(var.private_subnets)].id : var.public_subnets[0].id
  iam_instance_profile = var.ssm_instance_profile.name

  vpc_security_group_ids = [
    var.security_groups.core_servers.id,
    var.security_groups.external_web_access.id,
    var.security_groups.inbound_web_access.id
  ]

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    iops                  = 3000
    volume_size           = 50
    volume_type           = "gp3"
  }

  tags = {
    Name        = "${var.environment}-frontend-server-${count.index + 1}"
    Environment = var.environment
    PatchGroup  = "${var.environment}-cso-instances"
    Backup      = "required"
    Monitoring  = "enabled"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx amazon-ssm-agent nfs-utils java-21-amazon-corretto unzip
    systemctl enable --now amazon-ssm-agent
    
    # Create ecs user for CSO application
    useradd -m -s /bin/bash ecs
    mkdir -p /home/ecs
    chown ecs:ecs /home/ecs
    
    # Mount EFS first
    mkdir -p /opt/scripts
    mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 ${var.efs_dns_name}:/ /opt/scripts
    echo '${var.efs_dns_name}:/ /opt/scripts nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 0 0' >> /etc/fstab
    
    # Create /opt/install symlink immediately after EFS mount
    mkdir -p /opt/scripts/install
    rm -rf /opt/install 2>/dev/null || true
    ln -sf /opt/scripts/install /opt/install
    echo "Early symlink created: /opt/install -> $(readlink /opt/install)"
    
    # Simple nginx config using echo commands
    rm -f /etc/nginx/conf.d/default.conf
    echo 'server {' > /etc/nginx/conf.d/cso.conf
    echo '    listen 8102;' >> /etc/nginx/conf.d/cso.conf
    echo '    location /ui/management/login/system {' >> /etc/nginx/conf.d/cso.conf
    echo '        add_header Content-Type "text/html";' >> /etc/nginx/conf.d/cso.conf
    echo '        return 200 "<html><body><h2>CSO Portal</h2><p>Loading...</p></body></html>";' >> /etc/nginx/conf.d/cso.conf
    echo '    }' >> /etc/nginx/conf.d/cso.conf
    echo '    location / {' >> /etc/nginx/conf.d/cso.conf
    echo '        add_header Content-Type "text/html";' >> /etc/nginx/conf.d/cso.conf
    echo '        return 200 "<html><body><h1>Frontend Server</h1><p>Loading...</p></body></html>";' >> /etc/nginx/conf.d/cso.conf
    echo '    }' >> /etc/nginx/conf.d/cso.conf
    echo '}' >> /etc/nginx/conf.d/cso.conf
    
    # Start nginx
    systemctl enable nginx
    systemctl start nginx
    
    # Log startup
    echo "Frontend server ${count.index + 1} started at $(date)" > /var/log/cso-setup.log
    echo "EFS mounted: $(df -h | grep /opt/scripts)" >> /var/log/cso-setup.log
    
    # Background setup process
    (
      sleep 30
      echo "Starting background setup at $(date)" >> /var/log/cso-setup.log
      
      # Wait for jump server to prepare all files (up to 60 minutes)
      echo "Waiting for jump server to prepare all files..." >> /var/log/cso-setup.log
      timeout 60m sh -c 'while ! [ -f /opt/scripts/.setup-complete ]; do echo "Waiting for jump server..."; sleep 30; done' >> /var/log/cso-setup.log 2>&1 || {
        echo "Jump server timeout - proceeding anyway" >> /var/log/cso-setup.log
      }
      
      # Create /opt/install symlink
      mkdir -p /opt/scripts/install
      rm -rf /opt/install 2>/dev/null || true
      ln -sf /opt/scripts/install /opt/install
      echo "Symlink created: /opt/install -> $(readlink /opt/install)"
      
      # Install additional packages
      dnf install -y python3 python3-pip nodejs unzip java-21-amazon-corretto >> /var/log/cso-setup.log 2>&1
      
      # Use setup script from EFS (prepared by jump server)
      if [ -f /opt/scripts/frontend-setup.sh ]; then
        echo "Running frontend setup script from EFS..." >> /var/log/cso-setup.log
        chmod +x /opt/scripts/frontend-setup.sh
        /opt/scripts/frontend-setup.sh "${var.environment}" "${count.index + 1}" "${var.efs_dns_name}" "${var.user_data_base.s3_bucket}" >> /var/log/cso-setup.log 2>&1
        echo "Setup script completed at $(date)" >> /var/log/cso-setup.log
      else
        echo "Setup script not found in EFS" >> /var/log/cso-setup.log
        ls -la /opt/scripts/ >> /var/log/cso-setup.log
      fi
    ) &
  EOF
  )

  depends_on = [var.efs_mount_targets]
}

##### Backend Servers #####
resource "aws_instance" "backend" {
  count         = var.ha ? 2 : 1
  ami           = var.ami_id
  instance_type = var.prod ? "c5.4xlarge" : "t2.2xlarge"
  subnet_id     = var.private_subnets[count.index % length(var.private_subnets)].id
  iam_instance_profile = var.ssm_instance_profile.name
  monitoring    = true

  vpc_security_group_ids = [
    var.security_groups.core_servers.id,
    var.security_groups.external_web_access.id
  ]

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    iops                  = 3000
    volume_size           = 50
    volume_type           = "gp3"
  }

  tags = {
    Name        = "${var.environment}-backend-server-${count.index + 1}"
    Environment = var.environment
    PatchGroup  = "${var.environment}-cso-instances"
    Backup      = "required"
    Monitoring  = "enabled"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y awscli python3 python3-pip nginx unzip java-21-amazon-corretto amazon-ssm-agent nfs-utils
    systemctl enable --now amazon-ssm-agent
    
    # Create ecs user for CSO application
    useradd -m -s /bin/bash ecs
    mkdir -p /home/ecs
    chown ecs:ecs /home/ecs
    
    # Mount EFS and wait for setup completion
    if [ -n "${var.efs_dns_name}" ]; then
      mkdir -p /opt/scripts
      mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 ${var.efs_dns_name}:/ /opt/scripts
      echo '${var.efs_dns_name}:/ /opt/scripts nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 0 0' >> /etc/fstab
      
      # Create /opt/install symlink immediately after EFS mount
      mkdir -p /opt/scripts/install
      rm -rf /opt/install 2>/dev/null || true
      ln -sf /opt/scripts/install /opt/install
      echo "Early symlink created: /opt/install -> $(readlink /opt/install)"
    fi
    
    # Wait for jump server to prepare all files (up to 60 minutes)
    echo "Waiting for jump server to prepare all files..."
    timeout 60m sh -c 'while ! [ -f /opt/scripts/.setup-complete ]; do echo "Waiting for jump server..."; sleep 30; done' || {
      echo "Jump server timeout - proceeding anyway"
    }
    
    # Create /opt/install symlink
    ln -sf /opt/scripts/install /opt/install
    
    # Use backend setup script from EFS (prepared by jump server)
    if [ -f /opt/scripts/backend-setup.sh ]; then
      chmod +x /opt/scripts/backend-setup.sh
      /opt/scripts/backend-setup.sh "${var.environment}" "${count.index + 1}" "${var.efs_dns_name}" "${var.user_data_base.s3_bucket}"
    else
      echo "Backend setup script not found in EFS"
      ls -la /opt/scripts/
    fi
  EOF
  )

  depends_on = [var.efs_mount_targets]
}

##### RabbitMQ Servers #####
resource "aws_instance" "rabbitmq" {
  count         = var.ha ? 2 : 1
  ami           = var.ami_id
  instance_type = "t2.xlarge"
  subnet_id     = var.private_subnets[count.index % length(var.private_subnets)].id
  iam_instance_profile = var.ssm_instance_profile.name

  vpc_security_group_ids = [
    var.security_groups.core_servers.id,
    var.security_groups.external_web_access.id
  ]

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    iops                  = 3000
    volume_size           = 50
    volume_type           = "gp3"
  }

  tags = {
    Name        = "${var.environment}-rabbitmq-server-${count.index + 1}"
    Environment = var.environment
    PatchGroup  = "${var.environment}-cso-instances"
    Backup      = "required"
    Monitoring  = "enabled"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y awscli amazon-ssm-agent nfs-utils java-21-amazon-corretto unzip
    systemctl enable --now amazon-ssm-agent
    
    # Create ecs user for CSO application
    useradd -m -s /bin/bash ecs
    mkdir -p /home/ecs
    chown ecs:ecs /home/ecs
    
    # Mount EFS if available
    if [ -n "${var.efs_dns_name}" ]; then
      mkdir -p /opt/scripts
      mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 ${var.efs_dns_name}:/ /opt/scripts
      echo '${var.efs_dns_name}:/ /opt/scripts nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 0 0' >> /etc/fstab
    fi
    
    # Wait for jump server to prepare all files (up to 60 minutes)
    echo "Waiting for jump server to prepare all files..."
    timeout 60m sh -c 'while ! [ -f /opt/scripts/.setup-complete ]; do echo "Waiting for jump server..."; sleep 30; done' || {
      echo "Jump server timeout - proceeding anyway"
    }
    
    # Create /opt/install symlink
    ln -sf /opt/scripts/install /opt/install
    
    # Use rabbitmq setup script from EFS (prepared by jump server)
    if [ -f /opt/scripts/rabbitmq-setup.sh ]; then
      chmod +x /opt/scripts/rabbitmq-setup.sh
      /opt/scripts/rabbitmq-setup.sh "${var.environment}" "${count.index + 1}" "${var.efs_dns_name}" "${var.user_data_base.s3_bucket}"
    else
      echo "RabbitMQ setup script not found in EFS"
      ls -la /opt/scripts/
    fi
  EOF
  )

  depends_on = [var.efs_mount_targets]
}

##### Keystone Servers #####
resource "aws_instance" "keystone" {
  count         = var.ha ? 2 : 1
  ami           = var.ami_id
  instance_type = var.prod ? "t2.xlarge" : "t2.medium"
  subnet_id     = var.private_subnets[count.index % length(var.private_subnets)].id
  iam_instance_profile = var.ssm_instance_profile.name

  vpc_security_group_ids = [
    var.security_groups.core_servers.id,
    var.security_groups.external_web_access.id
  ]

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    iops                  = 3000
    volume_size           = 50
    volume_type           = "gp3"
  }

  tags = {
    Name        = "${var.environment}-keystone-server-${count.index + 1}"
    Environment = var.environment
    PatchGroup  = "${var.environment}-cso-instances"
    Backup      = "required"
    Monitoring  = "enabled"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y awscli amazon-ssm-agent nfs-utils java-21-amazon-corretto unzip python3-pip
    systemctl enable --now amazon-ssm-agent
    
    # Install PyMySQL globally before keystone setup
    echo "Installing PyMySQL globally..."
    pip3 install PyMySQL
    
    # Create ecs user for CSO application
    useradd -m -s /bin/bash ecs
    mkdir -p /home/ecs
    chown ecs:ecs /home/ecs
    
    # Mount EFS if available
    if [ -n "${var.efs_dns_name}" ]; then
      mkdir -p /opt/scripts
      mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 ${var.efs_dns_name}:/ /opt/scripts
      echo '${var.efs_dns_name}:/ /opt/scripts nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 0 0' >> /etc/fstab
    fi
    
    # Wait for jump server to prepare all files (up to 60 minutes)
    echo "Waiting for jump server to prepare all files..."
    timeout 60m sh -c 'while ! [ -f /opt/scripts/.setup-complete ]; do echo "Waiting for jump server..."; sleep 30; done' || {
      echo "Jump server timeout - proceeding anyway"
    }
    
    # Create /opt/install symlink
    ln -sf /opt/scripts/install /opt/install
    
    # Use keystone setup script from EFS (prepared by jump server)
    if [ -f /opt/scripts/keystone-setup.sh ]; then
      chmod +x /opt/scripts/keystone-setup.sh
      /opt/scripts/keystone-setup.sh "${var.environment}" "${count.index + 1}" "${var.efs_dns_name}" "${var.user_data_base.s3_bucket}"
    else
      echo "Keystone setup script not found in EFS"
      ls -la /opt/scripts/
    fi
  EOF
  )

  depends_on = [var.efs_mount_targets]
}

##### Elastic IPs #####
resource "aws_eip" "jump-server" {
  instance = aws_instance.jump-server.id
  domain   = "vpc"

  tags = {
    Name        = "${var.environment}-jump-server-eip"
    Environment = var.environment
  }
}

resource "aws_eip" "frontend-server" {
  count    = var.ha ? 0 : 1
  instance = aws_instance.frontend[0].id
  domain   = "vpc"

  tags = {
    Name        = "${var.environment}-frontend-server-eip"
    Environment = var.environment
  }
}

##### Target Group Attachments for HA #####
resource "aws_lb_target_group_attachment" "frontend" {
  count            = var.ha ? length(aws_instance.frontend) : 0
  target_group_arn = var.frontend_target_group_arn
  target_id        = aws_instance.frontend[count.index].id
  port             = 8102
}