##### Secrets Manager - Auto-Generated Passwords #####

resource "random_password" "db_password" {
  length      = 16
  special     = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "service_password" {
  length  = 16
  special = true
}

resource "random_password" "keystone_password" {
  length  = 16
  special = true
}

resource "random_password" "rabbitmq_password" {
  length  = 16
  special = true
}

resource "random_password" "key_password" {
  length  = 16
  special = true
}

resource "random_password" "keystore_password" {
  length  = 16
  special = true
}

resource "random_password" "password_encryption_key" {
  length  = 32
  special = false
  upper   = true
  lower   = true
  numeric = true
}

resource "aws_secretsmanager_secret" "service_passwords" {
  name                    = "env-${local.ws}-passwords-v2"
  description             = "Auto-generated passwords for CSO environment ${local.ws}"
  recovery_window_in_days = 0
  kms_key_id             = aws_kms_key.secrets.arn
  force_overwrite_replica_secret = true

  tags = {
    Environment = local.ws
    ManagedBy   = "terraform"
    DataClass   = "sensitive"
  }
}

resource "aws_kms_key" "secrets" {
  description             = "KMS key for CSO secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Environment = local.ws
    ManagedBy   = "terraform"
    Purpose     = "secrets-encryption"
  }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${local.ws}-cso-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_secretsmanager_secret_version" "service_passwords" {
  secret_id = aws_secretsmanager_secret.service_passwords.id
  secret_string = jsonencode({
    db_password               = random_password.db_password.result
    service_password          = random_password.service_password.result
    keystone_password         = random_password.keystone_password.result
    rabbitmq_password         = random_password.rabbitmq_password.result
    key_password              = random_password.key_password.result
    keystore_password         = random_password.keystore_password.result
    password_encryption_key   = random_password.password_encryption_key.result
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}