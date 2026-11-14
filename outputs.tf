output "table_name" {
  description = "Value of DYNAMODB_TABLE for the service."
  value       = aws_dynamodb_table.execution_orders.name
}

output "table_arn" {
  description = "ARN of the table, for granting the pods' IAM role access to it."
  value       = aws_dynamodb_table.execution_orders.arn
}
