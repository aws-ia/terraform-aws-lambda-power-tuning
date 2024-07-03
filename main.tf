provider "aws" {
  region = var.aws_region
}
locals {
  defaultPowerValues = "[128,256,512,1024,1536,3008]"
  minRAM             = 128
  baseCosts          = jsonencode({"x86_64": {"ap-east-1":2.9e-9,"af-south-1":2.8e-9,"me-south-1":2.6e-9,"eu-south-1":2.4e-9,"ap-northeast-3":2.7e-9,"default":2.1e-9}, "arm64": {"default":1.7e-9}})
  sfCosts            = jsonencode({ "default" : 0.000025, "us-gov-west-1" : 0.00003, "ap-northeast-2" : 0.0000271, "eu-south-1" : 0.00002625, "af-south-1" : 0.00002975, "us-west-1" : 0.0000279, "eu-west-3" : 0.0000297, "ap-east-1" : 0.0000275, "me-south-1" : 0.0000275, "ap-south-1" : 0.0000285, "us-gov-east-1" : 0.00003, "sa-east-1" : 0.0000375 })
  visualizationURL   = "https://lambda-power-tuning.show/"

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

  cleaner_template = templatefile(
    "${path.module}/policies/cleaner.json",
    {
      account_id = var.aws_account_id
    }
  )

  executor_template = templatefile(
    "${path.module}/policies/executor.json",
    {
      account_id = var.aws_account_id
    }
  )

  initializer_template = templatefile(
    "${path.module}/policies/initializer.json",
    {
      account_id = var.aws_account_id
    }
  )

  optimizer_template = templatefile(
    "${path.module}/policies/optimizer.json",
    {
      account_id = var.aws_account_id
    }
  )
}

################################################################################
# State machine
################################################################################

resource "aws_sfn_state_machine" "state-machine" {
  name_prefix = var.lambda_function_prefix
  role_arn = aws_iam_role.sfn_role.arn

  definition = local.state_machine
}

################################################################################
# Roles and Policies
################################################################################

resource "aws_iam_role" "analyzer_role" {
  name                 = "${var.lambda_function_prefix}-analyzer_role"
  permissions_boundary = var.permissions_boundary
  path                 = local.role_path
  assume_role_policy   = file("${path.module}/policies/lambda.json")
}

resource "aws_iam_role" "optimizer_role" {
  name                 = "${var.lambda_function_prefix}-optimizer_role"
  permissions_boundary = var.permissions_boundary
  path                 = local.role_path
  assume_role_policy   = file("${path.module}/policies/lambda.json")
}

resource "aws_iam_role" "executor_role" {
  name                 = "${var.lambda_function_prefix}-executor_role"
  permissions_boundary = var.permissions_boundary
  path                 = local.role_path
  assume_role_policy   = file("${path.module}/policies/lambda.json")
}

resource "aws_iam_role" "initializer_role" {
  name                 = "${var.lambda_function_prefix}-initializer_role"
  permissions_boundary = var.permissions_boundary
  path                 = local.role_path
  assume_role_policy   = file("${path.module}/policies/lambda.json")
}

resource "aws_iam_role" "cleaner_role" {
  name                 = "${var.lambda_function_prefix}-cleaner_role"
  permissions_boundary = var.permissions_boundary
  path                 = local.role_path
  assume_role_policy   = file("${path.module}/policies/lambda.json")
}

resource "aws_iam_role" "sfn_role" {
  name                 = "${var.lambda_function_prefix}-sfn_role"
  permissions_boundary = var.permissions_boundary
  path                 = local.role_path
  assume_role_policy   = file("${path.module}/policies/sfn.json")
}


data "aws_iam_policy" "analyzer_policy" {
  name = "AWSLambdaExecute"
}

resource "aws_iam_policy_attachment" "execute-attach" {
  name       = "execute-attachment"
  roles      = [aws_iam_role.analyzer_role.name, aws_iam_role.optimizer_role.name, aws_iam_role.executor_role.name, aws_iam_role.cleaner_role.name, aws_iam_role.initializer_role.name]
  policy_arn = data.aws_iam_policy.analyzer_policy.arn
}

resource "aws_iam_policy" "executor_policy" {
  name        = "${var.lambda_function_prefix}_executor-policy"
  description = "Lambda power tuning policy - Executor - Terraform"

  policy = local.executor_template
}

resource "aws_iam_policy_attachment" "executor-attach" {
  name       = "executor-attachment"
  roles      = [aws_iam_role.executor_role.name]
  policy_arn = aws_iam_policy.executor_policy.arn
}

resource "aws_iam_policy" "initializer_policy" {
  name        = "${var.lambda_function_prefix}_initializer-policy"
  description = "Lambda power tuning policy - Initializer - Terraform"

  policy = local.initializer_template
}

resource "aws_iam_policy_attachment" "initializer-attach" {
  name       = "initializer-attachment"
  roles      = [aws_iam_role.initializer_role.name]
  policy_arn = aws_iam_policy.initializer_policy.arn
}

resource "aws_iam_policy" "cleaner_policy" {
  name        = "${var.lambda_function_prefix}_cleaner-policy"
  description = "Lambda power tuning policy - Cleaner - Terraform"

  policy = local.cleaner_template
}

resource "aws_iam_policy_attachment" "cleaner-attach" {
  name       = "cleaner-attachment"
  roles      = [aws_iam_role.cleaner_role.name]
  policy_arn = aws_iam_policy.cleaner_policy.arn
}

resource "aws_iam_policy" "optimizer_policy" {
  name        = "${var.lambda_function_prefix}_optimizer-policy"
  description = "Lambda power tuning policy - Optimizer - Terraform"

  policy = local.optimizer_template
}

resource "aws_iam_policy_attachment" "optimizer-attach" {
  name       = "optimizer-attachment"
  roles      = [aws_iam_role.optimizer_role.name]
  policy_arn = aws_iam_policy.optimizer_policy.arn
}


data "aws_iam_policy" "sfn_policy" {
  name = "AWSLambdaRole"
}

resource "aws_iam_policy_attachment" "sfn-attach" {
  name       = "sfn-attachment"
  roles      = [aws_iam_role.sfn_role.name]
  policy_arn = data.aws_iam_policy.sfn_policy.arn
}


################################################################################
# Lambda
################################################################################


resource "aws_lambda_function" "analyzer" {
  filename      = ".aws-lambda-power-tuning/src/app.zip"
  function_name = "${var.lambda_function_prefix}-analyzer"
  role          = aws_iam_role.analyzer_role.arn
  handler       = "analyzer.handler"
  layers        = [aws_lambda_layer_version.lambda_layer.arn]
  memory_size   = 128
  timeout       = 30

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = data.archive_file.app.output_base64sha256

  runtime = "nodejs20.x"

  dynamic "vpc_config" {
    for_each = var.vpc_subnet_ids != null && var.vpc_security_group_ids != null ? [true] : []
    content {
      security_group_ids = var.vpc_security_group_ids
      subnet_ids         = var.vpc_subnet_ids
    }
  }

  environment {
    variables = {
      defaultPowerValues = local.defaultPowerValues,
      minRAM             = local.minRAM,
      baseCosts          = local.baseCosts,
      sfCosts            = local.sfCosts,
      visualizationURL   = local.visualizationURL
    }
  }

  depends_on = [aws_lambda_layer_version.lambda_layer]
}

resource "aws_lambda_function" "cleaner" {
  filename      = ".aws-lambda-power-tuning/src/app.zip"
  function_name = "${var.lambda_function_prefix}-cleaner"
  role          = aws_iam_role.cleaner_role.arn
  handler       = "cleaner.handler"
  layers        = [aws_lambda_layer_version.lambda_layer.arn]
  memory_size   = 128
  timeout       = 40

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = data.archive_file.app.output_base64sha256

  runtime = "nodejs20.x"

  dynamic "vpc_config" {
    for_each = var.vpc_subnet_ids != null && var.vpc_security_group_ids != null ? [true] : []
    content {
      security_group_ids = var.vpc_security_group_ids
      subnet_ids         = var.vpc_subnet_ids
    }
  }

  environment {
    variables = {
      defaultPowerValues = local.defaultPowerValues,
      minRAM             = local.minRAM,
      baseCosts          = local.baseCosts,
      sfCosts            = local.sfCosts,
      visualizationURL   = local.visualizationURL
    }
  }

  depends_on = [aws_lambda_layer_version.lambda_layer]
}

resource "aws_lambda_function" "executor" {
  filename      = ".aws-lambda-power-tuning/src/app.zip"
  function_name = "${var.lambda_function_prefix}-executor"
  role          = aws_iam_role.executor_role.arn
  handler       = "executor.handler"
  layers        = [aws_lambda_layer_version.lambda_layer.arn]
  memory_size   = 128
  timeout       = 30

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = data.archive_file.app.output_base64sha256

  runtime = "nodejs20.x"

  dynamic "vpc_config" {
    for_each = var.vpc_subnet_ids != null && var.vpc_security_group_ids != null ? [true] : []
    content {
      security_group_ids = var.vpc_security_group_ids
      subnet_ids         = var.vpc_subnet_ids
    }
  }

  environment {
    variables = {
      defaultPowerValues = local.defaultPowerValues,
      minRAM             = local.minRAM,
      baseCosts          = local.baseCosts,
      sfCosts            = local.sfCosts,
      visualizationURL   = local.visualizationURL
    }
  }

  depends_on = [aws_lambda_layer_version.lambda_layer]
}

resource "aws_lambda_function" "initializer" {
  filename      = ".aws-lambda-power-tuning/src/app.zip"
  function_name = "${var.lambda_function_prefix}-initializer"
  role          = aws_iam_role.initializer_role.arn
  handler       = "initializer.handler"
  layers        = [aws_lambda_layer_version.lambda_layer.arn]
  memory_size   = 128
  timeout       = 30

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = data.archive_file.app.output_base64sha256

  runtime = "nodejs20.x"

  dynamic "vpc_config" {
    for_each = var.vpc_subnet_ids != null && var.vpc_security_group_ids != null ? [true] : []
    content {
      security_group_ids = var.vpc_security_group_ids
      subnet_ids         = var.vpc_subnet_ids
    }
  }

  environment {
    variables = {
      defaultPowerValues = local.defaultPowerValues,
      minRAM             = local.minRAM,
      baseCosts          = local.baseCosts,
      sfCosts            = local.sfCosts,
      visualizationURL   = local.visualizationURL
    }
  }

  depends_on = [aws_lambda_layer_version.lambda_layer]
}

resource "aws_lambda_function" "optimizer" {
  filename      = ".aws-lambda-power-tuning/src/app.zip"
  function_name = "${var.lambda_function_prefix}-optimizer"
  role          = aws_iam_role.optimizer_role.arn
  handler       = "optimizer.handler"
  layers        = [aws_lambda_layer_version.lambda_layer.arn]
  memory_size   = 128
  timeout       = 30

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = data.archive_file.app.output_base64sha256

  runtime = "nodejs20.x"

  dynamic "vpc_config" {
    for_each = var.vpc_subnet_ids != null && var.vpc_security_group_ids != null ? [true] : []
    content {
      security_group_ids = var.vpc_security_group_ids
      subnet_ids         = var.vpc_subnet_ids
    }
  }

  environment {
    variables = {
      defaultPowerValues = local.defaultPowerValues,
      minRAM             = local.minRAM,
      baseCosts          = local.baseCosts,
      sfCosts            = local.sfCosts,
      visualizationURL   = local.visualizationURL
    }
  }

  depends_on = [aws_lambda_layer_version.lambda_layer]
}


resource "aws_lambda_layer_version" "lambda_layer" {
  filename    = ".aws-lambda-power-tuning/src/layer.zip"
  layer_name  = "AWS-SDK-v3"
  description = "AWS SDK 3"
  compatible_architectures = ["x86_64"]
  compatible_runtimes = ["nodejs20.x"]

  depends_on = [data.archive_file.layer]
}


resource "null_resource" "build_layer" {
  provisioner "local-exec" {
    command     = "${path.module}/scripts/build_lambda_layer.sh"
    interpreter = ["bash"]
  }
  triggers = {
    always_run = "${timestamp()}"
  }
}

data "archive_file" "layer" {
  type        = "zip"
  source_dir  = ".aws-lambda-power-tuning/layer-sdk/src/"
  output_path = ".aws-lambda-power-tuning/src/layer.zip"

  depends_on = [
    null_resource.build_layer
  ]
}

data "archive_file" "app" {
  type        = "zip"
  output_path = ".aws-lambda-power-tuning/src/app.zip"
  source_dir  = ".aws-lambda-power-tuning/lambda/"

  depends_on = [
    null_resource.build_layer
  ]
}

