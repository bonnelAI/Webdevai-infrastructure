# EC2 Instance Outputs

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.wordpress_host.id
}

output "public_ip" {
  description = "Elastic IP address"
  value       = aws_eip.wordpress_host.public_ip
}

output "private_ip" {
  description = "Private IP address"
  value       = aws_instance.wordpress_host.private_ip
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.wordpress_host.id
}

output "ssh_command" {
  description = "SSH command to connect to instance"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_eip.wordpress_host.public_ip}"
}

output "dns_configuration" {
  description = "DNS record to create"
  value       = "Create A record: *.toctoc.com.au -> ${aws_eip.wordpress_host.public_ip}"
}
