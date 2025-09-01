##### Data Sources #####
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

##### Local Variables #####
locals {
  install_package = "files/installation-package-2.4-SPRINT4i.jar"            // Local path to CSO installation binaries
  setup_scripts   = "files/manual-installation-2.0-SPRINT10e-scripts.tar.gz"  // Local path to CSO manual installation scripts

  domain_suffix   = "CSO.ss"  // Added to FQDNs which are formed as <hostname>.<workspace_name>.<domain_suffix>
  db_admin_user   = "admin"   // RDS DB admin username

  ws              = terraform.workspace
  service-pw      = jsondecode(data.aws_secretsmanager_secret_version.service-passwords.secret_string)
  
  // Read variables from a YAML file rather than tfvars - allows us to use dynamic values per workspace
  env_raw         = yamldecode(file("env.${local.ws}.yaml"))
  env             = merge(local.env_raw, {
    admin_email = try(local.env_raw.admin_email, "admin@company.com")
  })

  // Calculate subnet CIDRs - currently just halves the CIDR passed for the VPC
  public_cidrs    = cidrsubnets(cidrsubnet(local.env.vpc_cidr,1,0), 1, 1)
  private_cidrs   = cidrsubnets(cidrsubnet(local.env.vpc_cidr,1,1), 1, 1)
  
  // Some useful AMI refs
  amis = {
    al2023  = data.aws_ami.amazon_linux_2023.id  // Latest Amazon Linux 2023
    mysql   = "ami-7d5e4919"
    mariadb = "ami-040284558d9f315b7"
  }

  // AWS AZs to use. Single node environments (non-ha) will be deployed in to the first AZ listed
  azs = {
    0 = "eu-west-2a"
    1 = "eu-west-2c" 
  }
}

