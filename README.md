# AWS Vault PKI Renewal Demo

This Terraform project provisions AWS infrastructure to demonstrate automatic TLS certificate renewal using Vault PKI.

## What This Demo Demonstrates

- An hourly AWS Lambda function requests a renewed certificate from Vault PKI.
- Lambda imports the renewed private key and certificate into AWS ACM.
- An Application Load Balancer (ALB) HTTPS listener uses that ACM certificate ARN.
- Certificate rotation happens in place by re-importing to the same ACM certificate ARN.

## Demo Components

- Vault policy and Vault AWS auth role for Lambda certificate issuance
- Bootstrap certificate issued from an existing Vault PKI mount and role
- ACM imported certificate (bootstrapped from Vault, rotated by Lambda)
- Application Load Balancer with HTTPS listener on port 443
- Lambda function (`python3.12`) for Vault AWS IAM login, renewal, and ACM import
- EventBridge rule (`rate(1 hour)`) triggering the Lambda
- IAM role and policy scoped for ACM import + CloudWatch Logs

## Permissions

### AWS

The AWS identity running Terraform needs permissions to create and manage:

- IAM roles/policies for Lambda
- Lambda function and permissions
- EventBridge rules and targets
- ACM certificate import
- EC2 security groups
- Elastic Load Balancing resources (ALB/listener)

### Vault

Terraform identity for Vault provider must be able to manage:

- Vault policy
- Vault AWS auth role
- Certificate issuance from an existing Vault PKI mount and PKI role

The Lambda Vault token created dynamically through AWS auth is scoped by the Terraform-managed policy to:

- `update` on `/<pki_mount>/issue/<pki_role>`

## Authentications

### AWS Authentication

Authenticate Terraform to AWS using your standard mechanism (environment variables, AWS profile, SSO, or assumed role).

### Vault Authentication

Terraform `vault` provider uses dynamic credentials from environment variables (for example HCP Terraform dynamic credentials), not a hardcoded token in code.

The Lambda authenticates to Vault using AWS IAM auth and its own execution role.

Required Lambda Vault environment values:

- `VAULT_ADDR`
- `VAULT_NAMESPACE` (optional)
- `VAULT_AUTH_PATH`
- `VAULT_AUTH_ROLE`
- `VAULT_PKI_PATH`
- `VAULT_PKI_ROLE`

## Features

- End-to-end automated hourly certificate renewal workflow
- ACM certificate reuse pattern to avoid ALB listener ARN changes
- Fixed-response HTTPS endpoint for simple certificate testing
- Parameterized networking, naming, and Vault PKI settings

## Usage

1. Create a `terraform.tfvars` with required values:

```hcl
aws_region                      = "ca-central-1"
name_prefix                     = "vault-pki"
renewed_certificate_common_name = "elb.demo.example.com"
vault_addr                      = "https://vault.example.com"
vault_namespace                 = ""
vault_auth_path                 = "aws"
vault_auth_role_name            = "lambda-cert-rotator"
vault_pki_path                  = "pki_int"
vault_pki_role                  = "elb-cert-issuer"

# Optional: provide these only if you want to use existing networking.
# If omitted, Terraform creates VPC + two public subnets automatically.
# vpc_id     = "vpc-xxxxxxxx"
# subnet_ids = ["subnet-aaaa", "subnet-bbbb"]
```

2. Run Terraform:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| allowed_ingress_cidrs | CIDR blocks allowed to access the ALB over HTTPS | `list(string)` | `["0.0.0.0/0"]` | no |
| aws_region | AWS region where resources are deployed | `string` | `"ca-central-1"` | no |
| initial_certificate_common_name | Common Name used for the bootstrap ACM certificate issued from Vault PKI | `string` | `"elb.demo.example.com"` | no |
| name_prefix | Prefix used for naming resources | `string` | `"vault-pki"` | no |
| renewed_certificate_common_name | Common Name requested from Vault PKI during renewal | `string` | `"elb.demo.example.com"` | no |
| renewed_certificate_ttl | TTL sent to Vault PKI for renewed certificates | `string` | `"24h"` | no |
| subnet_ids | Subnet IDs for the application load balancer | `list(string)` | `[]` | no |
| tags | Tags applied to all resources | `map(string)` | `{}` | no |
| vault_addr | Vault address used by the renewal Lambda | `string` | n/a | yes |
| vault_auth_path | Vault auth mount path used by the renewal Lambda | `string` | `"aws"` | no |
| vault_auth_role_name | Vault AWS auth role name used by the renewal Lambda | `string` | `"lambda-cert-rotator"` | no |
| vault_auth_token_max_ttl | Vault token max TTL in seconds for Lambda login | `number` | `7200` | no |
| vault_auth_token_ttl | Vault token TTL in seconds for Lambda login | `number` | `3600` | no |
| vault_namespace | Vault namespace used by the renewal Lambda | `string` | `""` | no |
| vault_pki_path | Vault PKI mount path used by the renewal Lambda | `string` | `"pki_int"` | no |
| vault_pki_role | Vault PKI role used by the renewal Lambda | `string` | `"elb-cert-issuer"` | no |
| vpc_cidr_block | CIDR block used when auto-creating VPC networking | `string` | `"10.10.0.0/24"` | no |
| vpc_id | VPC ID where the ALB security group is created | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| acm_certificate_arn | ACM certificate ARN used by ALB and rotated by Lambda |
| alb_dns_name | DNS name of the demo ALB |
| lambda_function_name | Name of the certificate renewal Lambda function |
| listener_arn | ARN of the HTTPS listener using the ACM certificate |
| vault_auth_backend_path | Vault auth backend path configured for Lambda AWS IAM login |
| vault_pki_role_name | Vault PKI role name used by Lambda to issue certificates |

## External Documentation

- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule
- https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/auth_backend
- https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/aws_auth_backend_role
- https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_secret_backend_role
- https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_secret_backend_cert
- https://developer.hashicorp.com/vault/api-docs/secret/pki#generate-certificate-and-key
- https://developer.hashicorp.com/vault/docs/auth/aws
- https://docs.aws.amazon.com/acm/latest/APIReference/API_ImportCertificate.html
