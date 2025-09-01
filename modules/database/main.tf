##### RDS Database Module #####

resource "aws_iam_role" "rds-monitoring-role" {
  name = "${var.environment}-rds-monitoring-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRole",
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "rds-monitoring-role" {
  role       = aws_iam_role.rds-monitoring-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_subnet_group" "main" {
  name        = "${var.environment}-rds-subnets"
  description = "${var.environment} Private Subnets"
  subnet_ids  = [for subnet in var.private_subnets : subnet.id]
}

resource "aws_db_instance" "main" {
  identifier                   = "${var.environment}-db"
  instance_class               = var.prod ? "db.c5.4xlarge" : "db.t3.2xlarge"
  engine                       = "mysql"
  engine_version               = "8.0.42"
  db_subnet_group_name         = aws_db_subnet_group.main.name
  multi_az                     = var.ha
  vpc_security_group_ids       = [var.core_servers_security_group_id]
  username                     = var.db_admin_user
  manage_master_user_password  = true
  deletion_protection          = var.prod
  allocated_storage            = 50
  max_allocated_storage        = 1000
  storage_encrypted            = true
  backup_retention_period      = var.prod ? 30 : 7
  backup_window               = "03:00-04:00"
  maintenance_window          = "sun:04:00-sun:05:00"
  skip_final_snapshot          = !var.prod
  final_snapshot_identifier    = var.prod ? "${var.environment}-db-final-snapshot" : null
  copy_tags_to_snapshot        = true
  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds-monitoring-role.arn

  tags = {
    "Name"        = "${var.environment}-db"
    "Environment" = var.environment
    "autostart"   = "no"
    "autostop"    = "no"
  }

  lifecycle {
    ignore_changes = [
      tags.autostart,
      tags.autostop,
      monitoring_interval
    ]
  }
}