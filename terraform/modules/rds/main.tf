resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

# DB is only reachable from EKS node SG on 5432 — no public access, no 0.0.0.0/0
resource "aws_security_group" "db" {
  name   = "${var.identifier}-db-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.allowed_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# Master password generated and stored by RDS in Secrets Manager —
# it never appears in Terraform state or code.
resource "aws_db_instance" "this" {
  identifier                  = var.identifier
  engine                      = "postgres"
  engine_version              = var.engine_version
  instance_class              = var.instance_class
  allocated_storage           = 20
  max_allocated_storage       = 100
  db_name                     = var.db_name
  username                    = "app_admin"
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.this.name
  vpc_security_group_ids      = [aws_security_group.db.id]
  multi_az                    = var.multi_az
  publicly_accessible         = false
  storage_encrypted           = true
  backup_retention_period     = 7
  deletion_protection         = var.environment == "prod"
  skip_final_snapshot         = var.environment != "prod"
  tags                        = merge(var.tags, { Environment = var.environment })
}
