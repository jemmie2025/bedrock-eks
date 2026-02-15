# RDS Module - Outputs

output "mysql_endpoint" {
  description = "MySQL RDS endpoint"
  value       = aws_db_instance.mysql.endpoint
}

output "mysql_address" {
  description = "MySQL RDS address"
  value       = aws_db_instance.mysql.address
}

output "mysql_port" {
  description = "MySQL RDS port"
  value       = aws_db_instance.mysql.port
}

output "mysql_database" {
  description = "MySQL database name"
  value       = aws_db_instance.mysql.db_name
}

output "mysql_username" {
  description = "MySQL username"
  value       = aws_db_instance.mysql.username
  sensitive   = true
}

output "postgres_endpoint" {
  description = "PostgreSQL RDS endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "postgres_address" {
  description = "PostgreSQL RDS address"
  value       = aws_db_instance.postgres.address
}

output "postgres_port" {
  description = "PostgreSQL RDS port"
  value       = aws_db_instance.postgres.port
}

output "postgres_database" {
  description = "PostgreSQL database name"
  value       = aws_db_instance.postgres.db_name
}

output "postgres_username" {
  description = "PostgreSQL username"
  value       = aws_db_instance.postgres.username
  sensitive   = true
}

output "mysql_secret_arn" {
  description = "ARN of the Secrets Manager secret for MySQL credentials"
  value       = aws_secretsmanager_secret.mysql_credentials.arn
}

output "postgres_secret_arn" {
  description = "ARN of the Secrets Manager secret for PostgreSQL credentials"
  value       = aws_secretsmanager_secret.postgres_credentials.arn
}