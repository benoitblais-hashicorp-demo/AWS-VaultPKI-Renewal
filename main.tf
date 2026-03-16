locals {
  name_prefix      = var.name_prefix
  create_network   = var.vpc_id == "" && length(var.subnet_ids) == 0
  effective_vpc_id = local.create_network ? aws_vpc.this[0].id : var.vpc_id
  effective_subnet_ids = local.create_network ? [
    aws_subnet.public_a[0].id,
    aws_subnet.public_b[0].id
  ] : var.subnet_ids
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/renew_certificate.py"
  output_path = "${path.module}/lambda/renew_certificate.zip"
}

resource "vault_policy" "lambda_pki_issue" {
  name = "${local.name_prefix}-lambda-pki-issue"

  policy = <<-EOT
path "${var.vault_pki_path}/issue/${vault_pki_secret_backend_role.elb_cert_issuer.name}" {
  capabilities = ["update"]
}
EOT
}

resource "vault_aws_auth_backend_role" "lambda" {
  backend                  = var.vault_auth_path
  role                     = var.vault_auth_role_name
  auth_type                = "iam"
  resolve_aws_unique_ids   = false
  bound_iam_principal_arns = [aws_iam_role.lambda.arn]
  token_policies           = [vault_policy.lambda_pki_issue.name]
  token_ttl                = var.vault_auth_token_ttl
  token_max_ttl            = var.vault_auth_token_max_ttl
}

resource "vault_pki_secret_backend_role" "elb_cert_issuer" {
  backend          = var.vault_pki_path
  name             = var.vault_pki_role
  allow_subdomains = true
  allowed_domains  = var.vault_allowed_domains
  max_ttl          = "86400"
}

resource "vault_pki_secret_backend_cert" "initial" {
  backend     = var.vault_pki_path
  name        = vault_pki_secret_backend_role.elb_cert_issuer.name
  common_name = var.initial_certificate_common_name
  ttl         = var.renewed_certificate_ttl

  depends_on = [vault_pki_secret_backend_role.elb_cert_issuer]
}

resource "aws_acm_certificate" "imported" {
  private_key       = vault_pki_secret_backend_cert.initial.private_key
  certificate_body  = vault_pki_secret_backend_cert.initial.certificate
  certificate_chain = length(trimspace(vault_pki_secret_backend_cert.initial.ca_chain)) > 0 ? vault_pki_secret_backend_cert.initial.ca_chain : vault_pki_secret_backend_cert.initial.issuing_ca

  tags = var.tags
}

resource "aws_vpc" "this" {
  count = local.create_network ? 1 : 0

  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${local.name_prefix}-vpc" })
}

resource "aws_subnet" "public_a" {
  count = local.create_network ? 1 : 0

  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 1, 0)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(var.tags, { Name = "${local.name_prefix}-public-a" })
}

resource "aws_subnet" "public_b" {
  count = local.create_network ? 1 : 0

  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 1, 1)
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = merge(var.tags, { Name = "${local.name_prefix}-public-b" })
}

resource "aws_internet_gateway" "this" {
  count = local.create_network ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  tags = merge(var.tags, { Name = "${local.name_prefix}-igw" })
}

resource "aws_route_table" "public" {
  count = local.create_network ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-public-rt" })
}

resource "aws_route_table_association" "public_a" {
  count = local.create_network ? 1 : 0

  subnet_id      = aws_subnet.public_a[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "public_b" {
  count = local.create_network ? 1 : 0

  subnet_id      = aws_subnet.public_b[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb"
  description = "Security group for ALB TLS listener"
  vpc_id      = local.effective_vpc_id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_lb" "this" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.effective_subnet_ids

  tags = var.tags
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.imported.arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Certificate renewal demo endpoint"
      status_code  = "200"
    }
  }
}

resource "aws_iam_role" "lambda" {
  name = "${local.name_prefix}-renewal-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "lambda" {
  name = "${local.name_prefix}-renewal-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "acm:ImportCertificate",
          "acm:DescribeCertificate"
        ]
        Resource = aws_acm_certificate.imported.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

resource "aws_lambda_function" "renewal" {
  function_name = "${local.name_prefix}-certificate-renewal"
  role          = aws_iam_role.lambda.arn
  handler       = "renew_certificate.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      ACM_CERTIFICATE_ARN = aws_acm_certificate.imported.arn
      VAULT_ADDR          = var.vault_addr
      VAULT_NAMESPACE     = var.vault_namespace
      VAULT_AUTH_PATH     = var.vault_auth_path
      VAULT_AUTH_ROLE     = vault_aws_auth_backend_role.lambda.role
      VAULT_PKI_PATH      = var.vault_pki_path
      VAULT_PKI_ROLE      = vault_pki_secret_backend_role.elb_cert_issuer.name
      CERT_COMMON_NAME    = var.renewed_certificate_common_name
      CERT_TTL            = var.renewed_certificate_ttl
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "hourly" {
  name                = "${local.name_prefix}-certificate-renewal-hourly"
  description         = "Run certificate renewal every hour"
  schedule_expression = "rate(1 hour)"

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.hourly.name
  target_id = "renewal-lambda"
  arn       = aws_lambda_function.renewal.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.renewal.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.hourly.arn
}

