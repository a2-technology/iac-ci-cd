variable "workload_name" {
  description = "(Required) The name of the workload"
  type        = string
}

variable "sso_role_name" {
  description = "(Required) The name of the SSO role created by IAM Identity Center"
  type        = string
}

variable "region" {
  description = "(Required) The region where the SSO role is created"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "(Required) The environment these resources are supporting"
  type        = string
}