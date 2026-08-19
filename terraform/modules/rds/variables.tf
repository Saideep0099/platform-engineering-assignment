variable "identifier"         { type = string }
variable "environment"        { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }

variable "allowed_sg_id" {
  type        = string
  description = "SG of EKS nodes allowed to connect"
}

variable "instance_class" {
  type    = string
  default = "db.t3.medium"
}

variable "engine_version" {
  type    = string
  default = "16.3"
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "db_name" {
  type    = string
  default = "enrollment"
}

variable "tags" {
  type    = map(string)
  default = {}
}