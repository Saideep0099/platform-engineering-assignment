module "platform" {
  source                 = "../../"
  environment            = var.environment
  cluster_name           = var.cluster_name
  vpc_cidr               = var.vpc_cidr
  azs                    = var.azs
  public_subnets         = var.public_subnets
  private_subnets        = var.private_subnets
  node_desired_size      = var.node_desired_size
  node_min_size          = var.node_min_size
  node_max_size          = var.node_max_size
  node_security_group_id = var.node_security_group_id
}

variable "environment"            { type = string }
variable "cluster_name"           { type = string }
variable "vpc_cidr"               { type = string }
variable "azs"                    { type = list(string) }
variable "public_subnets"         { type = list(string) }
variable "private_subnets"        { type = list(string) }
variable "node_desired_size"      { type = number }
variable "node_min_size"          { type = number }
variable "node_max_size"          { type = number }
variable "node_security_group_id" { type = string }
