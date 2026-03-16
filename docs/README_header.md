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
