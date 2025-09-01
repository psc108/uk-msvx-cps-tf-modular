output "bucket_name" {
  description = "S3 bucket name for CSO files"
  value       = aws_s3_bucket.cso_files.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.cso_files.arn
}