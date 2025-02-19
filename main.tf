locals {
  default_power_values = "[128,256,512,1024,1536,3008]"
  min_ram              = 128
  base_costs = jsonencode({
    "x86_64" : {
      "ap-east-1" : 2.9e-9, "af-south-1" : 2.8e-9, "me-south-1" : 2.6e-9, "eu-south-1" : 2.4e-9,
      "ap-northeast-3" : 2.7e-9, "default" : 2.1e-9
    }, "arm64" : { "default" : 1.7e-9 }
  })
  sf_costs = jsonencode({
    "default" : 0.000025, "us-gov-west-1" : 0.00003, "ap-northeast-2" : 0.0000271, "eu-south-1" : 0.00002625,
    "af-south-1" : 0.00002975, "us-west-1" : 0.0000279, "eu-west-3" : 0.0000297, "ap-east-1" : 0.0000275,
    "me-south-1" : 0.0000275, "ap-south-1" : 0.0000285, "us-gov-east-1" : 0.00003, "sa-east-1" : 0.0000375
  })
  visualization_url = "https://lambda-power-tuning.show/"

  role_path = var.role_path_override != "" ? var.role_path_override : "/${var.lambda_function_prefix}/"

  state_machine = templatefile(
    "${path.module}/state_machines/aws_lambda_power_tuning_state_machine.json",
    {
      initializerArn = aws_lambda_function.initializer.arn,
      executorArn    = aws_lambda_function.executor.arn,
      cleanerArn     = aws_lambda_function.cleaner.arn,
      analyzerArn    = aws_lambda_function.analyzer.arn,
      optimizerArn   = aws_lambda_function.optimizer.arn
    }
  )
  lambda_runtime = "nodejs20.x"
}

data "aws_caller_identity" "current" {}


################################################################################
# State machine
################################################################################

resource "aws_sfn_state_machine" "state_machine" {
  name_prefix = var.lambda_function_prefix
  role_arn    = aws_iam_role.sfn_role.arn

  definition = local.state_machine
}

################################################################################
# Roles and Policies
################################################################################

data "aws_iam_policy_document" "cleaner" {
  statement {
    sid = "1"
    actions = [
      "lambda:GetAlias",
      "lambda:DeleteAlias",
      "lambda:DeleteFunction"
    ]
    resources = ["arn:aws:lambda:*:${data.aws_caller_identity.current.account_id}:function:*"]
  }
}

data "aws_iam_policy_document" "executor" {
  statement {
    sid = "1"
    actions = [
      "lambda:InvokeFunction",
      "lambda:GetFunctionConfiguration"
    ]
    resources = ["arn:aws:lambda:*:${data.aws_caller_identity.current.account_id}:function:*"]
  }
}

data "aws_iam_policy_document" "initializer" {
  statement {
    sid = "1"
    actions = [
      "lambda:GetFunctionConfiguration"
    ]
    resources = ["arn:aws:lambda:*:${data.aws_caller_identity.current.account_id}:function:*"]
  }
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid = "1"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "sfn" {
  statement {
    sid = "1"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "optimizer" {
  statement {
    sid = "1"
    actions = [
      "lambda:GetAlias",
      "lambda:PublishVersion",
      "lambda:UpdateFunctionConfiguration",
      "lambda:GetFunctionConfiguration",
      "lambda:CreateAlias",
      "lambda:UpdateAlias"
    ]
    resources = ["arn:aws:lambda:*:${data.aws_caller_identity.current.account_id}:function:*"]
  }
}

resource "aws_iam_role" "analyzer_role" {
  name                 = "${var.lambda_function_prefix}-analyzer_role"
  permissions_boundary = var.permissions_boundary
  path                 = local.role_path
  assume_role_policy   = data.aws_iam_policy_document.lambda.json
  tags                 = var.tags
}

resource "aws_iam_role" "optimizer_role" {
  name                 = "${var.lambda_function_prefix}-optimizer_role"
  permissions_boundary = var.permissions_boundary
  path                 = local.role_path
  assume_role_policy   = data.aws_iam_policy_document.lambda.json
  tags                 = var.tags
}

resource "aws_iam_role" "executor_role" {
  name                 = "${var.lambda_function_prefix}-executor_role"
  permissions_boundary = var.permissions_boundary
  path                 = local.role_path
  assume_role_policy   = data.aws_iam_policy_document.lambda.json
  tags                 = var.tags
}

resource "aws_iam_role" "initializer_role" {
  name                 = "${var.lambda_function_prefix}-initializer_role"
  permissions_boundary = var.permissions_boundary
  path                 = local.role_path
  assume_role_policy   = data.aws_iam_policy_document.lambda.json
  tags                 = var.tags
}

resource "aws_iam_role" "cleaner_role" {
  name                 = "${var.lambda_function_prefix}-cleaner_role"
  permissions_boundary = var.permissions_boundary
  path                 = local.role_path
  assume_role_policy   = data.aws_iam_policy_document.lambda.json
  tags                 = var.tags
}

resource "aws_iam_role" "sfn_role" {
  name                 = "${var.lambda_function_prefix}-sfn_role"
  permissions_boundary = var.permissions_boundary
  path                 = local.role_path
  assume_role_policy   = data.aws_iam_policy_document.sfn.json
  tags                 = var.tags
}


data "aws_iam_policy" "analyzer_policy" {
  name = "AWSLambdaExecute"
}

resource "aws_iam_role_policy_attachment" "execute_attach" {
  for_each = toset([
    aws_iam_role.analyzer_role.name,
    aws_iam_role.optimizer_role.name,
    aws_iam_role.executor_role.name,
    aws_iam_role.cleaner_role.name,
    aws_iam_role.initializer_role.name
  ])
  role       = each.key
  policy_arn = data.aws_iam_policy.analyzer_policy.arn
}

resource "aws_iam_policy" "executor_policy" {
  name        = "${var.lambda_function_prefix}_executor-policy"
  description = "Lambda power tuning policy - Executor - Terraform"
  policy      = data.aws_iam_policy_document.executor.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "executor_attach" {
  role       = aws_iam_role.executor_role.name
  policy_arn = aws_iam_policy.executor_policy.arn
}

resource "aws_iam_policy" "initializer_policy" {
  name        = "${var.lambda_function_prefix}_initializer-policy"
  description = "Lambda power tuning policy - Initializer - Terraform"
  policy      = data.aws_iam_policy_document.initializer.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "initializer_attach" {
  role       = aws_iam_role.initializer_role.name
  policy_arn = aws_iam_policy.initializer_policy.arn
}

resource "aws_iam_policy" "cleaner_policy" {
  name        = "${var.lambda_function_prefix}_cleaner-policy"
  description = "Lambda power tuning policy - Cleaner - Terraform"
  policy      = data.aws_iam_policy_document.cleaner.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "cleaner_attach" {
  role       = aws_iam_role.cleaner_role.name
  policy_arn = aws_iam_policy.cleaner_policy.arn
}

resource "aws_iam_policy" "optimizer_policy" {
  name        = "${var.lambda_function_prefix}_optimizer-policy"
  description = "Lambda power tuning policy - Optimizer - Terraform"
  policy      = data.aws_iam_policy_document.optimizer.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "optimizer_attach" {
  role       = aws_iam_role.optimizer_role.name
  policy_arn = aws_iam_policy.optimizer_policy.arn
}


data "aws_iam_policy" "sfn_policy" {
  name = "AWSLambdaRole"
}

resource "aws_iam_role_policy_attachment" "sfn_attach" {
  role       = aws_iam_role.sfn_role.name
  policy_arn = data.aws_iam_policy.sfn_policy.arn
}


################################################################################
# Lambda
################################################################################


resource "aws_lambda_function" "analyzer" {
  filename      = "src/aws-lambda-power-tuning/src/app.zip"
  function_name = "${var.lambda_function_prefix}-analyzer"
  role          = aws_iam_role.analyzer_role.arn
  handler       = "analyzer.handler"
  layers = [
    aws_lambda_layer_version.lambda_layer.arn
  ]
  memory_size = 128
  timeout     = 30

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = data.archive_file.app.output_base64sha256

  runtime = local.lambda_runtime

  dynamic "vpc_config" {
    for_each = var.vpc_subnet_ids != null && var.vpc_security_group_ids != null ? [true] : []
    content {
      security_group_ids = var.vpc_security_group_ids
      subnet_ids         = var.vpc_subnet_ids
    }
  }

  environment {
    variables = {
      defaultPowerValues = local.default_power_values,
      minRAM             = local.min_ram,
      baseCosts          = local.base_costs,
      sfCosts            = local.sf_costs,
      visualizationURL   = local.visualization_url
    }
  }

  depends_on = [aws_lambda_layer_version.lambda_layer]
  tags       = var.tags
}

resource "aws_lambda_function" "cleaner" {
  filename      = "src/aws-lambda-power-tuning/src/app.zip"
  function_name = "${var.lambda_function_prefix}-cleaner"
  role          = aws_iam_role.cleaner_role.arn
  handler       = "cleaner.handler"
  layers = [
    aws_lambda_layer_version.lambda_layer.arn
  ]
  memory_size = 128
  timeout     = 40

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = data.archive_file.app.output_base64sha256

  runtime = local.lambda_runtime

  dynamic "vpc_config" {
    for_each = var.vpc_subnet_ids != null && var.vpc_security_group_ids != null ? [true] : []
    content {
      security_group_ids = var.vpc_security_group_ids
      subnet_ids         = var.vpc_subnet_ids
    }
  }

  environment {
    variables = {
      defaultPowerValues = local.default_power_values,
      minRAM             = local.min_ram,
      baseCosts          = local.base_costs,
      sfCosts            = local.sf_costs,
      visualizationURL   = local.visualization_url
    }
  }

  depends_on = [aws_lambda_layer_version.lambda_layer]
  tags       = var.tags
}

resource "aws_lambda_function" "executor" {
  filename      = "src/aws-lambda-power-tuning/src/app.zip"
  function_name = "${var.lambda_function_prefix}-executor"
  role          = aws_iam_role.executor_role.arn
  handler       = "executor.handler"
  layers = [
    aws_lambda_layer_version.lambda_layer.arn
  ]
  memory_size = 128
  timeout     = 30

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = data.archive_file.app.output_base64sha256

  runtime = local.lambda_runtime

  dynamic "vpc_config" {
    for_each = var.vpc_subnet_ids != null && var.vpc_security_group_ids != null ? [true] : []
    content {
      security_group_ids = var.vpc_security_group_ids
      subnet_ids         = var.vpc_subnet_ids
    }
  }

  environment {
    variables = {
      defaultPowerValues = local.default_power_values,
      minRAM             = local.min_ram,
      baseCosts          = local.base_costs,
      sfCosts            = local.sf_costs,
      visualizationURL   = local.visualization_url
    }
  }

  depends_on = [aws_lambda_layer_version.lambda_layer]
  tags       = var.tags
}

resource "aws_lambda_function" "initializer" {
  filename      = "src/aws-lambda-power-tuning/src/app.zip"
  function_name = "${var.lambda_function_prefix}-initializer"
  role          = aws_iam_role.initializer_role.arn
  handler       = "initializer.handler"
  layers = [
    aws_lambda_layer_version.lambda_layer.arn
  ]
  memory_size = 128
  timeout     = 30

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = data.archive_file.app.output_base64sha256

  runtime = local.lambda_runtime

  dynamic "vpc_config" {
    for_each = var.vpc_subnet_ids != null && var.vpc_security_group_ids != null ? [true] : []
    content {
      security_group_ids = var.vpc_security_group_ids
      subnet_ids         = var.vpc_subnet_ids
    }
  }

  environment {
    variables = {
      defaultPowerValues = local.default_power_values,
      minRAM             = local.min_ram,
      baseCosts          = local.base_costs,
      sfCosts            = local.sf_costs,
      visualizationURL   = local.visualization_url
    }
  }

  depends_on = [aws_lambda_layer_version.lambda_layer]
  tags       = var.tags
}

resource "aws_lambda_function" "optimizer" {
  filename      = "src/aws-lambda-power-tuning/src/app.zip"
  function_name = "${var.lambda_function_prefix}-optimizer"
  role          = aws_iam_role.optimizer_role.arn
  handler       = "optimizer.handler"
  layers = [
    aws_lambda_layer_version.lambda_layer.arn
  ]
  memory_size = 128
  timeout     = 30

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = data.archive_file.app.output_base64sha256

  runtime = local.lambda_runtime

  dynamic "vpc_config" {
    for_each = var.vpc_subnet_ids != null && var.vpc_security_group_ids != null ? [true] : []
    content {
      security_group_ids = var.vpc_security_group_ids
      subnet_ids         = var.vpc_subnet_ids
    }
  }

  environment {
    variables = {
      defaultPowerValues = local.default_power_values,
      minRAM             = local.min_ram,
      baseCosts          = local.base_costs,
      sfCosts            = local.sf_costs,
      visualizationURL   = local.visualization_url
    }
  }

  depends_on = [aws_lambda_layer_version.lambda_layer]
  tags       = var.tags
}


resource "aws_lambda_layer_version" "lambda_layer" {
  filename                 = "src/aws-lambda-power-tuning/src/layer.zip"
  layer_name               = "AWS-SDK-v3"
  description              = "AWS SDK 3"
  compatible_architectures = ["x86_64"]
  compatible_runtimes      = [local.lambda_runtime]

  depends_on = [
    data.archive_file.layer
  ]

}

resource "terraform_data" "always_replace" {
  input = timestamp()
}

resource "terraform_data" "build_layer" {
  provisioner "local-exec" {
    command     = "${path.module}/scripts/build_lambda_layer.sh"
    interpreter = ["bash"]
  }
  lifecycle {
    replace_triggered_by = [terraform_data.always_replace]
  }
}

data "archive_file" "layer" {
  type        = "zip"
  source_dir  = "src/aws-lambda-power-tuning/layer-sdk/src/"
  output_path = "src/aws-lambda-power-tuning/src/layer.zip"

  depends_on = [
    terraform_data.build_layer
  ]
}

data "archive_file" "app" {
  type        = "zip"
  output_path = "src/aws-lambda-power-tuning/src/app.zip"
  source_dir  = "src/aws-lambda-power-tuning/lambda/"

  depends_on = [
    terraform_data.build_layer
  ]
}

