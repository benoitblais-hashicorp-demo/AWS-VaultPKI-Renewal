# AWS Vault PKI Renewal Demo

This Terraform project provisions AWS infrastructure to demonstrate automatic TLS certificate renewal using Vault PKI.

## What This Demo Demonstrates

- An hourly AWS Lambda function requests a renewed certificate from Vault PKI.
- Lambda imports the renewed private key and certificate into AWS ACM.
- An Application Load Balancer (ALB) HTTPS listener uses that ACM certificate ARN.
- Certificate rotation happens in place by re-importing to the same ACM certificate ARN.

> **Note:** You do not need to wait one hour to demonstrate renewal. You can manually invoke the Lambda at any time to trigger an immediate certificate rotation.

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

## How Certificate Renewal Works in this Demo

This demo uses an event-driven model where EventBridge invokes a Lambda every hour, and the Lambda handles Vault authentication, certificate issuance, and ACM import.

### The Workflow

1. EventBridge triggers the Lambda on `rate(1 hour)`.
2. Lambda authenticates to Vault using AWS IAM auth (`VAULT_AUTH_PATH` and `VAULT_AUTH_ROLE`).
3. Lambda requests a new certificate from Vault PKI (`VAULT_PKI_PATH` and `VAULT_PKI_ROLE`).
4. Lambda imports the renewed certificate and private key into the same ACM certificate ARN.
5. ALB HTTPS listener continues using that ACM ARN, now backed by the renewed material.

### Run the Demo Immediately (No 1-Hour Wait)

You can force a renewal by invoking the Lambda manually:

```bash
aws lambda invoke \
  --function-name <lambda_function_name> \
  --payload '{}' \
  response.json
```

Then verify results:

- Check Lambda logs in CloudWatch Logs for a successful renewal message.
- Confirm ACM certificate `Not Before/Not After` timestamps were updated.
- Test the ALB HTTPS endpoint to validate certificate rotation behavior.
