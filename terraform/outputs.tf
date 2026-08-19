output "cluster_name"       { value = module.eks.cluster_name }
output "ecr_repository_url" { value = module.ecr_enrollment.repository_url }
output "rds_endpoint"       { value = module.rds.endpoint }
output "irsa_role_arn"      { value = module.irsa_enrollment.role_arn }
