##### Security Groups and Keys Module #####

##### IAM Role for SSM #####
resource "aws_iam_role" "ssm_role" {
  name = "${var.environment}-ec2-ssm-role"

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

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm_patch_management" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMPatchAssociation"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

##### S3 Access Policy for File Downloads #####
resource "aws_iam_role_policy" "s3_file_access" {
  name = "${var.environment}-s3-file-access"
  role = aws_iam_role.ssm_role.id

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
          var.cso_files_bucket_arn,
          "${var.cso_files_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.environment}-ec2-ssm-profile"
  role = aws_iam_role.ssm_role.name
}



##### SSL Certificates #####
resource "tls_private_key" "root-ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "root-ca" {
  private_key_pem       = tls_private_key.root-ca.private_key_pem
  allowed_uses          = ["cert_signing"]
  validity_period_hours = 30 * 365 * 24 // 30 years
  is_ca_certificate     = true
  subject {
    organization        = "DXC"
    organizational_unit = "SSP"
    common_name         = "${var.environment} DXC SSP Root CA"
  }
}

resource "tls_private_key" "backend-lb" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "backend-lb" {
  private_key_pem = tls_private_key.backend-lb.private_key_pem
  dns_names       = ["*.${var.environment}.CSO.ss"]
}

resource "tls_locally_signed_cert" "backend-lb" {
  cert_request_pem      = tls_cert_request.backend-lb.cert_request_pem
  ca_private_key_pem    = tls_private_key.root-ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.root-ca.cert_pem
  validity_period_hours = 365 * 24 // 1 year
  allowed_uses          = ["server_auth"]
}

resource "aws_acm_certificate" "backend-lb" {
  private_key       = tls_private_key.backend-lb.private_key_pem
  certificate_body  = tls_locally_signed_cert.backend-lb.cert_pem
  certificate_chain = tls_self_signed_cert.root-ca.cert_pem
  count             = var.ha ? 1 : 0

  lifecycle {
    create_before_destroy = true
  }
}

##### Security Groups #####
resource "aws_security_group" "jump-server-sg" {
  name        = "${var.environment}-jump-server-sg"
  description = "Security group for jump server"
  vpc_id      = var.vpc_id



  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-jump-server-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "core-servers-sg" {
  name        = "${var.environment}-core-servers-sg"
  description = "Security group for core servers"
  vpc_id      = var.vpc_id



  ingress {
    description = "All traffic between core servers"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "MySQL/Aurora"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-core-servers-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "external-web-access-sg" {
  name        = "${var.environment}-external-web-access-sg"
  description = "Security group for external web access"
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-external-web-access-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "inbound-web-access-sg" {
  name        = "${var.environment}-inbound-web-access-sg"
  description = "Security group for inbound web access"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "CSO Frontend"
    from_port   = 8102
    to_port     = 8102
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Keystone"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-inbound-web-access-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "efs" {
  name        = "${var.environment}-efs-sg"
  description = "Security group for EFS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS from core servers"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.core-servers-sg.id]
  }

  ingress {
    description     = "NFS from jump server"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.jump-server-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-efs-sg"
    Environment = var.environment
  }
}