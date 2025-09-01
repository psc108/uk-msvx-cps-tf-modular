##### Secrets Manager for Service Passwords #####
resource "random_password" "service_passwords" {
  count   = 2
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "service_passwords" {
  name                    = "${var.environment}-service-passwords"
  description             = "Service passwords for ${var.environment} environment"
  recovery_window_in_days = 0  # Immediate deletion when needed

  tags = {
    Environment = var.environment
    Purpose     = "service-authentication"
  }
}

resource "aws_secretsmanager_secret_version" "service_passwords" {
  secret_id = aws_secretsmanager_secret.service_passwords.id
  secret_string = jsonencode({
    keystone_password = "KeystonePass123"  # Simple password without special characters
    service_password  = random_password.service_passwords[0].result
    admin_password    = random_password.service_passwords[1].result
  })
}