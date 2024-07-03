output "analyzer_function_arn" {
  description = "Analyzer lambda function ARN"
  value       = try(module.aws_power_tuning.analyzer_function, null)
}

output "cleaner_function_arn" {
  description = "Cleaner lambda function ARN"
  value       = try(module.aws_power_tuning.cleaner_function.arn, null)
}

output "executor_function_arn" {
  description = "Executor lambda function ARN"
  value       = try(module.aws_power_tuning.executor_function, null)
}

output "initializer_function_arn" {
  description = "Initializer lambda function ARN"
  value       = try(module.aws_power_tuning.initializer_function, null)
}

output "optimizer_function_arn" {
  description = "optimizer lambda function ARN"
  value       = try(module.aws_power_tuning.optimizer_function, null)
}