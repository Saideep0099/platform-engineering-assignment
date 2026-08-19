# Root composition — wires the reusable modules together.
# Environments (dev/prod) call this via their own backend + tfvars.

locals {
  tags = {
    Project     = "enrollment-platform"
    Environment = var.environment
    Owner       = "platform-engineering"
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source          = "./modules/vpc"
  name            = "${var.environment}-platform"
  environment     = var.environment
  vpc_cidr        = var.vpc_cidr
  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  cluster_name    = var.cluster_name
  tags            = local.tags
}

module "eks" {
  source             = "./modules/eks"
  cluster_name       = var.cluster_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
  tags               = local.tags
}

module "ecr_enrollment" {
  source          = "./modules/ecr"
  repository_name = "enrollment-service"
  environment     = var.environment
  tags            = local.tags
}

module "rds" {
  source             = "./modules/rds"
  identifier         = "${var.environment}-enrollment-db"
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  allowed_sg_id      = var.node_security_group_id
  multi_az           = var.environment == "prod"
  tags               = local.tags
}

# S3 bucket the app reads from via IRSA (Part D)
resource "aws_s3_bucket" "enrollment_docs" {
  bucket = "${var.environment}-enrollment-docs-${data.aws_caller_identity.current.account_id}"
  tags   = local.tags
}

resource "aws_s3_bucket_public_access_block" "enrollment_docs" {
  bucket                  = aws_s3_bucket.enrollment_docs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_caller_identity" "current" {}

# IRSA role for the enrollment service — least privilege: read-only, one prefix
module "irsa_enrollment" {
  source               = "./modules/iam"
  role_name            = "${var.environment}-enrollment-irsa"
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.oidc_provider_url
  namespace            = "enrollment"
  service_account_name = "enrollment-service"
  tags                 = local.tags
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadEnrollmentDocs"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.enrollment_docs.arn}/enrollments/*"
      },
      {
        Sid      = "ListPrefixOnly"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.enrollment_docs.arn
        Condition = { StringLike = { "s3:prefix" = ["enrollments/*"] } }
      }
    ]
  })
}
