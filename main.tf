##### CSO Shared Services Portal - Modular Terraform Configuration #####

##### Data Sources #####
data "aws_secretsmanager_secret_version" "service-passwords" {
  secret_id  = aws_secretsmanager_secret.service_passwords.id
  depends_on = [aws_secretsmanager_secret_version.service_passwords]
}



##### Networking Module #####
module "networking" {
  source = "./modules/networking"

  environment    = local.ws
  vpc_name       = local.env.vpc_name
  vpc_cidr       = local.env.vpc_cidr
  public_cidrs   = local.public_cidrs
  private_cidrs  = local.private_cidrs
  azs            = local.azs
  ha             = local.env.ha
  admin_email    = local.env.admin_email
  admin_phone_number = local.env.admin_phone_number
  backend_lb_certificate_arn = local.env.ha ? module.security.backend_lb_certificate.arn : null
}

##### Security Module #####
module "security" {
  source = "./modules/security"

  environment               = local.ws
  vpc_id                   = module.networking.vpc_id
  jump_server_access_cidrs = local.env.jump_server_access_cidrs
  ha                       = local.env.ha
  cso_files_bucket_arn     = module.s3_files.bucket_arn
}

##### S3 Files Module #####
module "s3_files" {
  source = "./modules/s3-files"

  environment = local.ws
}

##### File Preparation Module (Optional) #####
module "file_prep" {
  source = "./modules/file-prep"
  count  = var.enable_file_prep ? 1 : 0

  environment     = local.ws
  s3_bucket_name  = module.s3_files.bucket_name
  s3_bucket_arn   = module.s3_files.bucket_arn
  
  depends_on = [module.s3_files]
}

##### Storage Module #####
module "storage" {
  source = "./modules/storage"

  environment            = local.ws
  private_subnets        = module.networking.private_subnets
  public_subnets         = module.networking.public_subnets
  efs_security_group_id  = module.security.security_groups.efs.id
  install_package_path   = local.install_package
  setup_scripts_path     = local.setup_scripts
}

##### Database Module #####
module "database" {
  source = "./modules/database"

  environment                     = local.ws
  private_subnets                 = module.networking.private_subnets
  core_servers_security_group_id  = module.security.security_groups.core_servers.id
  db_admin_user                   = local.db_admin_user
  prod                            = local.env.prod
  ha                              = local.env.ha
}

##### Compute Module #####
module "compute" {
  source = "./modules/compute"

  environment               = local.ws
  ami_id                    = local.amis.al2023
  public_subnets            = values(module.networking.public_subnets)
  private_subnets           = values(module.networking.private_subnets)
  security_groups           = module.security.security_groups
  # SSH keys removed - using SSM for access
  root_ca_private_key       = module.security.root_ca_private_key.private_key_pem
  root_ca_cert              = module.security.root_ca_cert.cert_pem
  efs_mount_targets         = module.storage.efs_mount_targets
  efs_dns_name              = module.storage.efs_file_system.dns_name
  
  # Configuration variables
  prod                      = local.env.prod
  ha                        = local.env.ha
  debug                     = var.debug
  
  # Passwords
  service_password          = local.service-pw.service_password
  keystone_password         = local.service-pw.keystone_password
  rabbitmq_password         = local.service-pw.rabbitmq_password
  key_password              = local.service-pw.key_password
  
  # File paths and content
  setup_scripts_path        = local.setup_scripts
  install_package_path      = local.install_package
  
  # DNS zone name for RabbitMQ configuration
  private_zone_name         = "${local.ws}.${local.domain_suffix}"
  mysql_hostname            = module.database.db_instance.endpoint
  ssm_instance_profile      = module.security.ssm_instance_profile
  frontend_target_group_arn = module.networking.frontend_target_group != null ? module.networking.frontend_target_group.arn : null
  
  # User data base
  user_data_base = {
    run_cmds     = []
    packages     = []
    files        = []
    efs-dns-name = module.storage.efs_file_system.dns_name
    s3_bucket    = module.s3_files.bucket_name
  }

  depends_on = [
    module.networking,
    module.security,
    module.storage,
    module.database
  ]
}

##### DNS Module #####
module "dns" {
  source = "./modules/dns"

  environment         = local.ws
  domain_suffix       = local.domain_suffix
  vpc_id              = module.networking.vpc_id
  db_endpoint         = module.database.db_instance.endpoint
  ha                  = local.env.ha
  frontend_instances  = module.compute.frontend_instances
  backend_instances   = module.compute.backend_instances
  keystone_instances  = module.compute.keystone_instances
  rabbitmq_instances  = module.compute.rabbitmq_instances

  depends_on = [
    module.compute,
    module.database
  ]
}