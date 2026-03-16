output "acm_certificate_arn" {
  description = "ACM certificate ARN used by ALB and rotated by Lambda"
  value       = aws_acm_certificate.imported.arn
}

output "alb_dns_name" {
  description = "DNS name of the demo ALB"
  value       = aws_lb.this.dns_name
}

output "lambda_function_name" {
  description = "Name of the certificate renewal Lambda function"
  value       = aws_lambda_function.renewal.function_name
}

output "listener_arn" {
  description = "ARN of the HTTPS listener using the ACM certificate"
  value       = aws_lb_listener.https.arn
}

output "vault_auth_backend_path" {
  description = "Vault auth backend path configured for Lambda AWS IAM login"
  value       = var.vault_auth_path
}

output "vault_pki_role_name" {
  description = "Vault PKI role name used by Lambda to issue certificates"
  value       = var.vault_pki_role
}
