variable "environment" { type = string }

variable "cost_center" {
  type    = string
  default = "platform"
}

variable "cluster_name"    { type = string }
variable "vpc_cidr"        { type = string }
variable "azs"             { type = list(string) }
variable "public_subnets"  { type = list(string) }
variable "private_subnets" { type = list(string) }

variable "node_desired_size"      { type = number }
variable "node_min_size"          { type = number }
variable "node_max_size"          { type = number }
variable "node_security_group_id" { type = string }