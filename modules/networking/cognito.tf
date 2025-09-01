##### AWS Cognito for ALB Authentication #####

data "aws_region" "current" {}

resource "aws_cognito_user_pool" "main_v2" {
  count = var.ha ? 1 : 0
  name  = "${var.environment}-cso-users-v2"

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  admin_create_user_config {
    allow_admin_create_user_only = true
    invite_message_template {
      email_message = "Your CSO username is {username} and temporary password is {####}. Please change it on first login."
      email_subject = "CSO Access - Temporary Password"
      sms_message   = "Your CSO username is {username} and temporary password is {####}"
    }
  }

  auto_verified_attributes = ["email"]
  
  # MFA Configuration
  mfa_configuration = "ON"  # MFA required for all users
  
  software_token_mfa_configuration {
    enabled = true
  }
  
  user_pool_add_ons {
    advanced_security_mode = "OFF"
  }
  
  device_configuration {
    challenge_required_on_new_device      = false
    device_only_remembered_on_user_prompt = false
  }
  
  schema {
    attribute_data_type = "String"
    name               = "email"
    required           = true
    mutable            = true
  }
  


  tags = {
    Environment = var.environment
    Purpose     = "alb-authentication"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cognito_user_pool_domain" "main" {
  count        = var.ha ? 1 : 0
  domain       = "${var.environment}-cso-auth-v2"
  user_pool_id = aws_cognito_user_pool.main_v2[0].id
}

resource "aws_cognito_user_pool_client" "alb_client" {
  count        = var.ha ? 1 : 0
  name         = "${var.environment}-cso-alb-client"
  user_pool_id = aws_cognito_user_pool.main_v2[0].id

  generate_secret                      = true
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  
  callback_urls = [
    "https://${aws_lb.frontend[0].dns_name}/oauth2/idpresponse"
  ]
  
  logout_urls = [
    "https://${aws_lb.frontend[0].dns_name}/logout"
  ]

  supported_identity_providers = ["COGNITO"]
  
  explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_CUSTOM_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# Create default admin user
resource "aws_cognito_user" "admin" {
  count        = var.ha ? 1 : 0
  user_pool_id = aws_cognito_user_pool.main_v2[0].id
  username     = "csoadmin"
  
  attributes = {
    email          = var.admin_email
    email_verified = true
  }
  
  temporary_password = random_password.cognito_temp_password[0].result
  message_action     = "SUPPRESS"
  
  lifecycle {
    ignore_changes = [temporary_password]
  }
}

resource "random_password" "cognito_temp_password" {
  count   = var.ha ? 1 : 0
  length  = 16
  special = true
  numeric = true
  upper   = true
  lower   = true
  
  # Ensure at least one of each required character type
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
}