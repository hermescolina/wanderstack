output "instance_public_ips" {
  description = "Public IPs of EC2 instances"
  value       = [for instance in aws_instance.example : instance.public_ip]
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.example.dns_name
}
