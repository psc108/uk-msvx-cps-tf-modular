##### ALB Authentication Configuration #####

# Separate resource to avoid circular dependency
# Commented out to bypass Cognito authentication for now
# resource "aws_lb_listener_rule" "cognito_auth" {
#   count        = var.ha ? 1 : 0
#   listener_arn = aws_lb_listener.frontend[0].arn
#   priority     = 100
# 
#   action {
#     type = "authenticate-oidc"
#     
#     authenticate_oidc {
#       authorization_endpoint = "https://${aws_cognito_user_pool_domain.main[0].domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/authorize"
#       client_id              = aws_cognito_user_pool_client.alb_client[0].id
#       client_secret          = aws_cognito_user_pool_client.alb_client[0].client_secret
#       issuer                 = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.main_v2[0].id}"
#       token_endpoint         = "https://${aws_cognito_user_pool_domain.main[0].domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/token"
#       user_info_endpoint     = "https://${aws_cognito_user_pool_domain.main[0].domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/userInfo"
#       
#       authentication_request_extra_params = {
#         display = "page"
#         prompt  = "login"
#       }
#     }
#   }
# 
#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.frontend[0].arn
#   }
# 
#   condition {
#     path_pattern {
#       values = ["/*"]
#     }
#   }
# 
#   depends_on = [
#     aws_cognito_user_pool_client.alb_client,
#     aws_cognito_user_pool_domain.main
#   ]
# }