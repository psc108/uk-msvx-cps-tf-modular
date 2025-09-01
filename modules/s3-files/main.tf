##### S3 Files Module - Upload Once, Reference Everywhere #####

resource "aws_s3_bucket" "cso_files" {
  bucket        = "${var.environment}-cso-files"
  force_destroy = var.environment != "prod"

  tags = {
    Environment = var.environment
    Purpose     = "cso-file-distribution"
  }
}

resource "aws_s3_bucket_versioning" "cso_files" {
  bucket = aws_s3_bucket.cso_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cso_files" {
  bucket = aws_s3_bucket.cso_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cso_files" {
  bucket = aws_s3_bucket.cso_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}



##### Files are uploaded via AWS CLI in deploy script #####
##### No Terraform resources needed for file uploads #####