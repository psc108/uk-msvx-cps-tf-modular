output "db_instance" {
  description = "RDS database instance"
  value       = aws_db_instance.main
}

output "db_master_user_secret" {
  description = "RDS master user secret managed by AWS"
  value       = aws_db_instance.main.master_user_secret
}