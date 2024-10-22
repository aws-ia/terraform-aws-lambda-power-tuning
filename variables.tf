################################################################################
# AWS Lambda power tuning vars
################################################################################

variable "lambda_function_prefix" {
  default     = "lambda_power_tuning"
  description = "Prefix used for the names of Lambda functions, Step Functions state machines, IAM roles, and IAM policies."
  type        = string
}

variable "role_path_override" {
  default     = ""
  type        = string
  description = "IAM Role path to use for each Lambda function's role, instead of the default path /lambda_power_tuning/ (see variable lambda_function_prefix)."
}

variable "permissions_boundary" {
  default     = null
  type        = string
  description = "ARN of the policy that is used to set the permissions boundary for the role."
}

variable "vpc_subnet_ids" {
  description = "List of subnet ids when Lambda Function should run in the VPC. Usually private or intra subnets."
  type        = list(string)
  default     = null
}

variable "vpc_security_group_ids" {
  description = "List of security group ids when Lambda Function should run in the VPC."
  type        = list(string)
  default     = null
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default     = { "app" : "lambda_power_tuning" }
}
