# RDS Module - Managed Databases for Production

################################################################################
# Random Password Generation
################################################################################

resource "random_password" "mysql" {
  length  = 16
  special = true
}

resource "random_password" "postgres" {
  length  = 16
  special = true
}

################################################################################
# DB Subnet Group
################################################################################

resource "aws_db_subnet_group" "main" {
  name       = "bedrock-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "bedrock-db-subnet-group"
    }
  )
}

################################################################################
# Security Group for RDS
################################################################################

resource "aws_security_group" "rds" {
  name_prefix = "bedrock-rds-sg"
  description = "Security group for RDS databases"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from EKS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.eks_security_group_id]
  }

  ingress {
    description     = "PostgreSQL from EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "bedrock-rds-sg"
    }
  )
}

################################################################################
# MySQL RDS Instance (for Catalog Service)
################################################################################

resource "aws_db_instance" "mysql" {
  identifier     = "bedrock-catalog-mysql"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "catalog"
  username = "catalogadmin"
  password = random_password.mysql.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 0
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  skip_final_snapshot       = true
  final_snapshot_identifier = "bedrock-catalog-mysql-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  tags = merge(
    var.tags,
    {
      Name    = "bedrock-catalog-mysql"
      Service = "catalog"
    }
  )
}

################################################################################
# PostgreSQL RDS Instance (for Orders Service)
################################################################################

resource "aws_db_instance" "postgres" {
  identifier     = "bedrock-orders-postgres"
  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "orders"
  username = "ordersadmin"
  password = random_password.postgres.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 0
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  skip_final_snapshot       = true
  final_snapshot_identifier = "bedrock-orders-postgres-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(
    var.tags,
    {
      Name    = "bedrock-orders-postgres"
      Service = "orders"
    }
  )
}

################################################################################
# AWS Secrets Manager for Database Credentials
################################################################################

resource "aws_secretsmanager_secret" "mysql_credentials" {
  name        = "bedrock/rds/mysql-credentials"
  description = "MySQL database credentials for Catalog service"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "mysql_credentials" {
  secret_id = aws_secretsmanager_secret.mysql_credentials.id
  secret_string = jsonencode({
    username = aws_db_instance.mysql.username
    password = random_password.mysql.result
    host     = aws_db_instance.mysql.address
    port     = aws_db_instance.mysql.port
    database = aws_db_instance.mysql.db_name
    endpoint = aws_db_instance.mysql.endpoint
  })
}

resource "aws_secretsmanager_secret" "postgres_credentials" {
  name        = "bedrock/rds/postgres-credentials"
  description = "PostgreSQL database credentials for Orders service"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "postgres_credentials" {
  secret_id = aws_secretsmanager_secret.postgres_credentials.id
  secret_string = jsonencode({
    username = aws_db_instance.postgres.username
    password = random_password.postgres.result
    host     = aws_db_instance.postgres.address
    port     = aws_db_instance.postgres.port
    database = aws_db_instance.postgres.db_name
    endpoint = aws_db_instance.postgres.endpoint
  })
}