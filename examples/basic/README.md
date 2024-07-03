<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.26 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.26 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_aws_power_tuning"></a> [aws\_power\_tuning](#module\_aws\_power\_tuning) | ../../ | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_analyzer_function_arn"></a> [analyzer\_function\_arn](#output\_analyzer\_function\_arn) | Analyzer lambda function ARN |
| <a name="output_cleaner_function_arn"></a> [cleaner\_function\_arn](#output\_cleaner\_function\_arn) | Cleaner lambda function ARN |
| <a name="output_executor_function_arn"></a> [executor\_function\_arn](#output\_executor\_function\_arn) | Executor lambda function ARN |
| <a name="output_initializer_function_arn"></a> [initializer\_function\_arn](#output\_initializer\_function\_arn) | Initializer lambda function ARN |
| <a name="output_optimizer_function_arn"></a> [optimizer\_function\_arn](#output\_optimizer\_function\_arn) | optimizer lambda function ARN |
<!-- END_TF_DOCS -->