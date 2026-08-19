variable "role_name"            { type = string }
variable "oidc_provider_arn"    { type = string }
variable "oidc_provider_url"    { type = string }
variable "namespace"            { type = string }
variable "service_account_name" { type = string }

variable "policy_json" {
  type        = string
  description = "Least-privilege inline policy"
}

variable "tags" {
  type    = map(string)
  default = {}
}