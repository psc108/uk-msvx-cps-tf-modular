##### SSM Patch Management Configuration #####

resource "aws_ssm_patch_baseline" "amazon_linux" {
  name             = "${var.environment}-amazon-linux-baseline"
  description      = "Patch baseline for Amazon Linux instances"
  operating_system = "AMAZON_LINUX_2"

  approval_rule {
    approve_after_days  = var.environment == "prod" ? 7 : 0
    compliance_level    = "HIGH"
    enable_non_security = true

    patch_filter {
      key    = "PRODUCT"
      values = ["AmazonLinux2"]
    }

    patch_filter {
      key    = "CLASSIFICATION"
      values = ["Security", "Bugfix"]
    }

    patch_filter {
      key    = "SEVERITY"
      values = ["Critical", "Important", "Medium", "Low"]
    }
  }

  tags = {
    Environment = var.environment
    Purpose     = "patch-management"
  }
}

resource "aws_ssm_patch_group" "cso_instances" {
  baseline_id = aws_ssm_patch_baseline.amazon_linux.id
  patch_group = "${var.environment}-cso-instances"
}

resource "aws_ssm_maintenance_window" "cso_patching" {
  name              = "${var.environment}-cso-patching-window"
  description       = "Maintenance window for CSO instance patching"
  duration          = 4
  cutoff            = 1
  schedule          = var.environment == "prod" ? "cron(0 2 ? * SUN *)" : "cron(0 2 ? * SAT *)"
  schedule_timezone = "Europe/London"

  tags = {
    Environment = var.environment
    Purpose     = "patch-management"
  }
}

resource "aws_ssm_maintenance_window_target" "cso_instances" {
  window_id     = aws_ssm_maintenance_window.cso_patching.id
  name          = "${var.environment}-cso-patch-targets"
  description   = "CSO instances for patching"
  resource_type = "INSTANCE"

  targets {
    key    = "tag:PatchGroup"
    values = ["${var.environment}-cso-instances"]
  }

  targets {
    key    = "tag:Environment"
    values = [var.environment]
  }
}

resource "aws_ssm_maintenance_window_task" "patch_task" {
  window_id        = aws_ssm_maintenance_window.cso_patching.id
  name             = "${var.environment}-patch-task"
  description      = "Patch CSO instances"
  task_type        = "RUN_COMMAND"
  task_arn         = "AWS-RunPatchBaseline"
  priority         = 1
  service_role_arn = aws_iam_role.ssm_maintenance_role.arn
  max_concurrency  = "50%"
  max_errors       = "1"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.cso_instances.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      document_version  = "$LATEST"
      timeout_seconds   = 3600
      
      parameter {
        name   = "Operation"
        values = ["Install"]
      }

      parameter {
        name   = "RebootOption"
        values = ["NoReboot"]
      }
    }
  }
}

resource "aws_iam_role" "ssm_maintenance_role" {
  name = "${var.environment}-ssm-maintenance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Purpose     = "ssm-maintenance"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_maintenance_policy" {
  role       = aws_iam_role.ssm_maintenance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMMaintenanceWindowRole"
}

resource "aws_ssm_association" "inventory_collection" {
  name = "AWS-GatherSoftwareInventory"

  targets {
    key    = "tag:Environment"
    values = [var.environment]
  }

  schedule_expression = "rate(1 day)"
  compliance_severity = "MEDIUM"

  parameters = {
    applications                = "Enabled"
    awsComponents              = "Enabled"
    customInventory            = "Enabled"
    instanceDetailedInformation = "Enabled"
    networkConfig              = "Enabled"
    services                   = "Enabled"
    windowsRegistry            = "Disabled"
    windowsRoles               = "Disabled"
    files                      = ""
  }

  output_location {
    s3_bucket_name = aws_s3_bucket.ssm_logs.bucket
    s3_key_prefix  = "inventory/"
  }
}

resource "aws_s3_bucket" "ssm_logs" {
  bucket        = "${var.environment}-cso-ssm-logs-${random_id.bucket_suffix.hex}"
  force_destroy = var.environment != "prod"

  tags = {
    Environment = var.environment
    Purpose     = "ssm-logs"
  }
}

resource "aws_s3_bucket_versioning" "ssm_logs" {
  bucket = aws_s3_bucket.ssm_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ssm_logs" {
  bucket = aws_s3_bucket.ssm_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ssm_logs" {
  bucket = aws_s3_bucket.ssm_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}