output "efs_file_system" {
  description = "EFS file system"
  value       = aws_efs_file_system.efs
}

output "efs_mount_targets" {
  description = "EFS mount targets"
  value       = aws_efs_mount_target.efs-mount-target
}

