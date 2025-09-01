##### File Preparation Module - Pre-Infrastructure File Distribution #####

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Minimal VPC for file preparation
resource "aws_vpc" "file_prep" {
  cidr_block           = "10.255.0.0/24"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name        = "${var.environment}-file-prep-vpc"
    Environment = var.environment
    Purpose     = "file-preparation"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "file_prep" {
  vpc_id = aws_vpc.file_prep.id
  
  tags = {
    Name        = "${var.environment}-file-prep-igw"
    Environment = var.environment
  }
}

# Public subnet
resource "aws_subnet" "file_prep" {
  vpc_id                  = aws_vpc.file_prep.id
  cidr_block              = "10.255.0.0/28"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  
  tags = {
    Name        = "${var.environment}-file-prep-subnet"
    Environment = var.environment
  }
}

# Route table
resource "aws_route_table" "file_prep" {
  vpc_id = aws_vpc.file_prep.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.file_prep.id
  }
  
  tags = {
    Name        = "${var.environment}-file-prep-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "file_prep" {
  subnet_id      = aws_subnet.file_prep.id
  route_table_id = aws_route_table.file_prep.id
}

# Security group for file prep instance
resource "aws_security_group" "file_prep" {
  name_prefix = "${var.environment}-file-prep-"
  vpc_id      = aws_vpc.file_prep.id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name        = "${var.environment}-file-prep-sg"
    Environment = var.environment
  }
}

# EFS file system for file preparation
resource "aws_efs_file_system" "file_prep" {
  creation_token = "${var.environment}-file-prep-efs"
  encrypted      = true
  
  performance_mode = "generalPurpose"
  throughput_mode  = "provisioned"
  provisioned_throughput_in_mibps = 100
  
  tags = {
    Name        = "${var.environment}-file-prep-efs"
    Environment = var.environment
    Purpose     = "file-preparation"
  }
}

# EFS mount target
resource "aws_efs_mount_target" "file_prep" {
  file_system_id  = aws_efs_file_system.file_prep.id
  subnet_id       = aws_subnet.file_prep.id
  security_groups = [aws_security_group.efs.id]
}

# Security group for EFS
resource "aws_security_group" "efs" {
  name_prefix = "${var.environment}-file-prep-efs-"
  vpc_id      = aws_vpc.file_prep.id
  
  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.file_prep.id]
  }
  
  tags = {
    Name        = "${var.environment}-file-prep-efs-sg"
    Environment = var.environment
  }
}

# IAM role for file prep instance
resource "aws_iam_role" "file_prep" {
  name = "${var.environment}-file-prep-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "file_prep" {
  name = "${var.environment}-file-prep-policy"
  role = aws_iam_role.file_prep.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "file_prep" {
  name = "${var.environment}-file-prep-profile"
  role = aws_iam_role.file_prep.name
}

# File preparation instance
resource "aws_instance" "file_prep" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.file_prep.id
  vpc_security_group_ids = [aws_security_group.file_prep.id]
  iam_instance_profile   = aws_iam_instance_profile.file_prep.name
  
  user_data = base64encode(templatefile("${path.module}/file-prep-userdata.sh", {
    efs_dns_name = aws_efs_file_system.file_prep.dns_name
    s3_bucket    = var.s3_bucket_name
    environment  = var.environment
  }))
  
  tags = {
    Name        = "${var.environment}-file-prep"
    Environment = var.environment
    Purpose     = "file-preparation"
  }
  
  depends_on = [
    aws_efs_mount_target.file_prep
  ]
}

# Wait for file preparation to complete
resource "null_resource" "wait_for_file_prep" {
  provisioner "local-exec" {
    command = "aws ec2 wait instance-status-ok --instance-ids ${aws_instance.file_prep.id}"
  }
  
  # Wait additional time for file copying
  provisioner "local-exec" {
    command = "powershell -Command Start-Sleep 300"  # 5 minutes for file operations
    interpreter = ["cmd", "/C"]
  }
  
  # Terminate the file prep instance after completion
  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.file_prep.id}"
    interpreter = ["cmd", "/C"]
  }
  
  depends_on = [aws_instance.file_prep]
}

data "aws_availability_zones" "available" {
  state = "available"
}