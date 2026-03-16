variable "vault_addr" {
  type        = string
  description = "(Required) Vault address used by the renewal Lambda"
}

variable "allowed_ingress_cidrs" {
  type        = list(string)
  description = "(Optional) CIDR blocks allowed to access the ALB over HTTPS"
  default     = ["0.0.0.0/0"]

  validation {
    condition = alltrue([
      for cidr in var.allowed_ingress_cidrs : can(regex("^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])/(3[0-2]|[12]?[0-9])$", cidr))
    ])
    error_message = "Each value in `allowed_ingress_cidrs` must be a valid IPv4 CIDR block (for example, 192.168.1.0/24 or 10.0.0.1/32)."
  }
}

variable "aws_region" {
  type        = string
  description = "(Optional) AWS region where resources are deployed"
  default     = "ca-central-1"
}

variable "initial_certificate_common_name" {
  type        = string
  description = "(Optional) Common Name used for the bootstrap ACM certificate issued from Vault PKI"
  default     = "elb.demo.example.com"
}

variable "name_prefix" {
  type        = string
  description = "(Optional) Prefix used for naming resources"
  default     = "vault-pki"
}

variable "renewed_certificate_common_name" {
  type        = string
  description = "(Optional) Common Name requested from Vault PKI during renewal"
  default     = "elb.demo.example.com"
}

variable "renewed_certificate_ttl" {
  type        = string
  description = "(Optional) TTL sent to Vault PKI for renewed certificates"
  default     = "24h"
}

variable "subnet_ids" {
  type        = list(string)
  description = "(Optional) Subnet IDs for the application load balancer"
  default     = []

  validation {
    condition = alltrue([
      for subnet_id in var.subnet_ids : can(regex("^subnet-([0-9a-f]{8}|[0-9a-f]{17})$", subnet_id))
    ])
    error_message = "Each value in `subnet_ids` must be a valid AWS subnet ID (for example, subnet-1234abcd or subnet-1234567890abcdef0)."
  }

  validation {
    condition = (
      (var.vpc_id == "" && length(var.subnet_ids) == 0) ||
      (var.vpc_id != "" && length(var.subnet_ids) >= 2)
    )
    error_message = "Provide both `vpc_id` and at least two `subnet_ids`, or provide neither to auto-create networking."
  }
}

variable "tags" {
  type        = map(string)
  description = "(Optional) Tags applied to all resources"
  default     = {}
}

variable "vault_allowed_domains" {
  type        = list(string)
  description = "(Optional) Allowed domains for certificates issued by the Vault PKI role"
  default     = ["demo.example.com"]
}

variable "vault_auth_path" {
  type        = string
  description = "(Optional) Vault auth mount path used by the renewal Lambda"
  default     = "aws"
}

variable "vault_auth_role_name" {
  type        = string
  description = "(Optional) Vault AWS auth role name used by the renewal Lambda"
  default     = "lambda-cert-rotator"
}

variable "vault_auth_token_max_ttl" {
  type        = number
  description = "(Optional) Vault token max TTL in seconds for Lambda login"
  default     = 7200
}

variable "vault_auth_token_ttl" {
  type        = number
  description = "(Optional) Vault token TTL in seconds for Lambda login"
  default     = 3600
}

variable "vault_namespace" {
  type        = string
  description = "(Optional) Vault namespace used by the renewal Lambda"
  default     = ""
}

variable "vault_pki_path" {
  type        = string
  description = "(Optional) Vault PKI mount path used by the renewal Lambda"
  default     = "pki-int"
}

variable "vault_pki_role" {
  type        = string
  description = "(Optional) Vault PKI role used by the renewal Lambda"
  default     = "elb-cert-issuer"
}

variable "vpc_cidr_block" {
  type        = string
  description = "(Optional) CIDR block used when auto-creating VPC networking"
  default     = "10.10.0.0/24"

  validation {
    condition = (
      can(cidrnetmask(var.vpc_cidr_block)) &&
      can(regex("^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])/(1[6-9]|2[0-7])$", var.vpc_cidr_block))
    )
    error_message = "`vpc_cidr_block` must be a valid IPv4 CIDR with prefix between /16 and /27 (for example, 10.10.0.0/24)."
  }
}

variable "vpc_id" {
  type        = string
  description = "(Optional) VPC ID where the ALB security group is created"
  default     = ""
}
