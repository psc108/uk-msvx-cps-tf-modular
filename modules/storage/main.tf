##### EFS Storage Module #####

resource "aws_efs_file_system" "efs" {
  creation_token   = "${var.environment}-efs"
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "provisioned"
  provisioned_throughput_in_mibps = 100
  
  tags = {
    Name        = "${var.environment}-install-scripts"
    Environment = var.environment
    Backup      = "required"
  }

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }
}

# Use private subnets for mount targets (they can reach public subnets in same VPC)
locals {
  mount_target_subnets = var.private_subnets
}

resource "aws_efs_mount_target" "efs-mount-target" {
  for_each        = local.mount_target_subnets
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = each.value.id
  security_groups = [var.efs_security_group_id]
}