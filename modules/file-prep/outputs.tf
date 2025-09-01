output "efs_file_system" {
  description = "EFS file system with prepared files"
  value = {
    id       = aws_efs_file_system.file_prep.id
    dns_name = aws_efs_file_system.file_prep.dns_name
    arn      = aws_efs_file_system.file_prep.arn
  }
}

output "file_prep_complete" {
  description = "File preparation completion status"
  value       = null_resource.wait_for_file_prep.id
}