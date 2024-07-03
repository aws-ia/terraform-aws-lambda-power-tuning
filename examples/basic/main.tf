#####################################################################################
# Terraform module examples are meant to show an _example_ on how to use a module
# per use-case. The code below should not be copied directly but referenced in order
# to build your own root module that invokes this module
#####################################################################################

locals {
  aws_region = "us-west-2"
}
data "aws_caller_identity" "current" {}

module "aws_power_tuning" {
  source  = "../../"
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region = local.aws_region
}