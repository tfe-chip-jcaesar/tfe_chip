output "name_servers" {
  value = aws_route53_zone.ss.name_servers
}

output "tfe_url" {
  value = module.tfe.tfe_url
}

output "tfe_admin_console_url" {
  value = module.tfe.tfe_admin_console_url
}

output "tfe_alb_dns_name" {
  value = module.tfe.tfe_alb_dns_name
}
