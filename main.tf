locals {
  common_tags = { "Owner" = "Jamie Caesar", "Company" = "Spacely Sprockets" }
}

module "tfe_vpc" {
  source = "./modules/tfe_vpc"

  vpc_name   = "tfe_vpc"
  cidr_block = "10.0.0.0/16"
  ipv6       = false
  azs        = ["a", "b"]
  tags       = local.common_tags
}

resource "aws_key_pair" "jamie" {
  key_name   = "jamie"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKRqLi7AYYkDPqK09dtXtpXoV5tSL1iu1XA2wcYKe8TVUxi+sLY6XuOmD7E6NkSi70AtEqoANIsBQOSfYfc0yOX0Q30UAuQTW8SC3VAevtguxj6Yy18P/auokaLLgDvaYdlRNPdF74P0Tu21sn4Ak8rS4LjIqj3NcRKgn2Ng0SHHaY+opp4VWBnhBWWiNnz4A1Ul4Y1etmFp6BJVoLV51L7CK9XhYYHWx2uEUMyMP1Yz9raDRIlBxH7ulaw4rPfkVf9oLdE+BuD0VycoDv2GYf9gWSxZ31cQN5yZ5eUZyUKg8ZV1M+FQmDzsyL3P6R6QrI1ELUSMr0Qjgoz2tB9M3X"
}

resource "aws_route53_zone" "ss" {
  name = "aws.shadowmonkey.com"

  tags = local.common_tags
}

resource "aws_kms_key" "tfe" {
  description             = "TFE key"
  deletion_window_in_days = 10
}

module "tfe" {
  source = "git@github.com:hashicorp/terraform-chip-tfe-is-terraform-aws-ptfe-v4-quick-install.git"

  friendly_name_prefix       = "ss"
  common_tags                = local.common_tags
  tfe_hostname               = "tfe.aws.shadowmonkey.com"
  tfe_license_file_path      = "./files/terraform-chip.rli"
  tfe_release_sequence       = "414"
  tfe_initial_admin_username = "tfe-jcaesar"
  tfe_initial_admin_email    = "jcaesar@presidio.com"
  tfe_initial_admin_pw       = "ThisAintSecure123!"
  tfe_initial_org_name       = "aws.shadowmonkey.com"
  tfe_initial_org_email      = "tfe-admins@aws.shadowmonkey.com"
  vpc_id                     = module.tfe_vpc.vpc_id
  alb_subnet_ids             = module.tfe_vpc.subnet_ids.public
  ec2_subnet_ids             = module.tfe_vpc.subnet_ids.private
  route53_hosted_zone_name   = aws_route53_zone.ss.name
  kms_key_arn                = aws_kms_key.tfe.arn
  ingress_cidr_alb_allow     = ["0.0.0.0/0"]
  ingress_cidr_ec2_allow     = ["68.126.204.187/32"] # my workstation IP
  ssh_key_pair               = aws_key_pair.jamie.key_name
  rds_subnet_ids             = module.tfe_vpc.subnet_ids.db
}
