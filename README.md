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

<!-- BEGIN_TF_DOCS -->
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

## Documentation

## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.6.0, < 2.0.0)

- <a name="requirement_archive"></a> [archive](#requirement\_archive) (~> 2.7)

- <a name="requirement_aws"></a> [aws](#requirement\_aws) (~> 6.36)

- <a name="requirement_vault"></a> [vault](#requirement\_vault) (~> 5.8)

## Modules

No modules.

## Required Inputs

The following input variables are required:

### <a name="input_vault_addr"></a> [vault\_addr](#input\_vault\_addr)

Description: (Required) Vault address used by the renewal Lambda

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_allowed_ingress_cidrs"></a> [allowed\_ingress\_cidrs](#input\_allowed\_ingress\_cidrs)

Description: (Optional) CIDR blocks allowed to access the ALB over HTTPS

Type: `list(string)`

Default:

```json
[
  "0.0.0.0/0"
]
```

### <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region)

Description: (Optional) AWS region where resources are deployed

Type: `string`

Default: `"ca-central-1"`

### <a name="input_initial_certificate_common_name"></a> [initial\_certificate\_common\_name](#input\_initial\_certificate\_common\_name)

Description: (Optional) Common Name used for the bootstrap ACM certificate issued from Vault PKI

Type: `string`

Default: `"elb.demo.example.com"`

### <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix)

Description: (Optional) Prefix used for naming resources

Type: `string`

Default: `"vault-pki"`

### <a name="input_renewed_certificate_common_name"></a> [renewed\_certificate\_common\_name](#input\_renewed\_certificate\_common\_name)

Description: (Optional) Common Name requested from Vault PKI during renewal

Type: `string`

Default: `"elb.demo.example.com"`

### <a name="input_renewed_certificate_ttl"></a> [renewed\_certificate\_ttl](#input\_renewed\_certificate\_ttl)

Description: (Optional) TTL sent to Vault PKI for renewed certificates

Type: `string`

Default: `"24h"`

### <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids)

Description: (Optional) Subnet IDs for the application load balancer

Type: `list(string)`

Default: `[]`

### <a name="input_tags"></a> [tags](#input\_tags)

Description: (Optional) Tags applied to all resources

Type: `map(string)`

Default: `{}`

### <a name="input_vault_auth_path"></a> [vault\_auth\_path](#input\_vault\_auth\_path)

Description: (Optional) Vault auth mount path used by the renewal Lambda

Type: `string`

Default: `"aws"`

### <a name="input_vault_auth_role_name"></a> [vault\_auth\_role\_name](#input\_vault\_auth\_role\_name)

Description: (Optional) Vault AWS auth role name used by the renewal Lambda

Type: `string`

Default: `"lambda-cert-rotator"`

### <a name="input_vault_auth_token_max_ttl"></a> [vault\_auth\_token\_max\_ttl](#input\_vault\_auth\_token\_max\_ttl)

Description: (Optional) Vault token max TTL in seconds for Lambda login

Type: `number`

Default: `7200`

### <a name="input_vault_auth_token_ttl"></a> [vault\_auth\_token\_ttl](#input\_vault\_auth\_token\_ttl)

Description: (Optional) Vault token TTL in seconds for Lambda login

Type: `number`

Default: `3600`

### <a name="input_vault_namespace"></a> [vault\_namespace](#input\_vault\_namespace)

Description: (Optional) Vault namespace used by the renewal Lambda

Type: `string`

Default: `""`

### <a name="input_vault_pki_path"></a> [vault\_pki\_path](#input\_vault\_pki\_path)

Description: (Optional) Vault PKI mount path used by the renewal Lambda

Type: `string`

Default: `"pki_int"`

### <a name="input_vault_pki_role"></a> [vault\_pki\_role](#input\_vault\_pki\_role)

Description: (Optional) Vault PKI role used by the renewal Lambda

Type: `string`

Default: `"elb-cert-issuer"`

### <a name="input_vpc_cidr_block"></a> [vpc\_cidr\_block](#input\_vpc\_cidr\_block)

Description: (Optional) CIDR block used when auto-creating VPC networking

Type: `string`

Default: `"10.10.0.0/24"`

### <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id)

Description: (Optional) VPC ID where the ALB security group is created

Type: `string`

Default: `""`

## Resources

The following resources are used by this module:

- [aws_acm_certificate.imported](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) (resource)
- [aws_cloudwatch_event_rule.hourly](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) (resource)
- [aws_cloudwatch_event_target.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) (resource)
- [aws_iam_role.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) (resource)
- [aws_iam_role_policy.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) (resource)
- [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) (resource)
- [aws_lambda_function.renewal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) (resource)
- [aws_lambda_permission.eventbridge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) (resource)
- [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) (resource)
- [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) (resource)
- [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) (resource)
- [aws_route_table_association.public_a](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) (resource)
- [aws_route_table_association.public_b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) (resource)
- [aws_security_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) (resource)
- [aws_subnet.public_a](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) (resource)
- [aws_subnet.public_b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) (resource)
- [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) (resource)
- [vault_aws_auth_backend_role.lambda](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/aws_auth_backend_role) (resource)
- [vault_pki_secret_backend_cert.initial](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_secret_backend_cert) (resource)
- [vault_policy.lambda_pki_issue](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/policy) (resource)
- [archive_file.lambda_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) (data source)
- [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) (data source)
- [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) (data source)

## Outputs

The following outputs are exported:

### <a name="output_acm_certificate_arn"></a> [acm\_certificate\_arn](#output\_acm\_certificate\_arn)

Description: ACM certificate ARN used by ALB and rotated by Lambda

### <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name)

Description: DNS name of the demo ALB

### <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name)

Description: Name of the certificate renewal Lambda function

### <a name="output_listener_arn"></a> [listener\_arn](#output\_listener\_arn)

Description: ARN of the HTTPS listener using the ACM certificate

### <a name="output_vault_auth_backend_path"></a> [vault\_auth\_backend\_path](#output\_vault\_auth\_backend\_path)

Description: Vault auth backend path configured for Lambda AWS IAM login

### <a name="output_vault_pki_role_name"></a> [vault\_pki\_role\_name](#output\_vault\_pki\_role\_name)

Description: Vault PKI role name used by Lambda to issue certificates

<!-- markdownlint-enable -->
# External Documentation

- [AWS ACM Certificate resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate)
- [AWS Application Load Balancer resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb)
- [AWS Load Balancer Listener resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener)
- [AWS Lambda Function resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function)
- [AWS EventBridge Rule resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule)
- [Vault Auth Backend resource](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/auth_backend)
- [Vault AWS Auth Backend Role resource](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/aws_auth_backend_role)
- [Vault Policy resource](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/policy)
- [Vault PKI Secret Backend Role resource](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_secret_backend_role)
- [Vault PKI Secret Backend Cert resource](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_secret_backend_cert)
- [Vault PKI issue certificate API](https://developer.hashicorp.com/vault/api-docs/secret/pki#generate-certificate-and-key)
- [Vault AWS auth method](https://developer.hashicorp.com/vault/docs/auth/aws)
- [AWS ACM ImportCertificate API](https://docs.aws.amazon.com/acm/latest/APIReference/API_ImportCertificate.html)
<!-- END_TF_DOCS -->