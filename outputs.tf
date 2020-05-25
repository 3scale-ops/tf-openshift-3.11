output "availability_zone" {
  description = "List of availability zones of the master instance"
  value       = aws_instance.master[*].*.availability_zone
}

output "master_public_hostname" {
  description = "List of public hostnames addresses assigned to the master instances"
  value       = aws_route53_record.master_node_dns[*].fqdn
}

output "worker_public_hostname" {
  description = "List of public hostnames addresses assigned to the worker instances"
  value       = aws_route53_record.worker_node_dns[*].*.fqdn
}

output "master_url" {
  description = "Master URL"
  value       = format("https://master.%s:8443/", var.dns_name)
}

output "console_url" {
  description = "Master DNS"
  value       = format("https://console.apps.%s/", var.dns_name)
}
