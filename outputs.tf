output "analyzer_function" {
  description = "Analyzer lambda function ARN"
  value       = try(aws_lambda_function.analyzer.arn, null)
}

output "cleaner_function" {
  description = "Cleaner lambda function ARN"
  value       = try(aws_lambda_function.cleaner.arn, null)
}

output "executor_function" {
  description = "Executor lambda function ARN"
  value       = try(aws_lambda_function.executor.arn, null)
}

output "initializer_function" {
  description = "Initializer lambda function ARN"
  value       = try(aws_lambda_function.initializer.arn, null)
}

output "optimizer_function" {
  description = "Optimizer lambda function ARN"
  value       = try(aws_lambda_function.optimizer.arn, null)
}
