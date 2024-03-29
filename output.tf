output "aws_region" {
  value = "${var.aws_region}"
}

output "clb_dns_name" {
  value       = aws_elb.sini_elb.dns_name
  description = "The domain name of the load balancer"
}
