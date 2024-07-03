#####################################################################################
# Terraform module examples are meant to show an _example_ on how to use a module
# per use-case. The code below should not be copied directly but referenced in order
# to build your own root module that invokes this module
#####################################################################################

locals {
  aws_region = "us-west-2"
}

module "aws_power_tuning" {
  source  = "github.com/aws-ia/terraform-aws-lambda-power-tuning"
  aws_account_id = "11223344556677"
  aws_region = local.aws_region
  lambda_function_prefix = "lambda_power_tuning"
  role_path_override = ""
  permissions_boundary = null
  vpc_subnet_ids = null
  vpc_security_group_ids = null
}