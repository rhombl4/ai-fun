# --------------------------------------
# Module Structure
# --------------------------------------
# 
# This Terraform module automates the deployment of an AWS Lambda function.
# The module ensures that the Lambda function is only updated when there are 
# changes to the source code or its dependencies.
# 
# **Important**: The Lambda function will not be redeployed if there are no changes 
# in the source code or dependencies, ensuring efficient and consistent deployments.
#
# **To force a redeployment** of the Lambda function, you can use the `make force-redeploy` 
# command, which will update the `.touch` file in the package. This will trigger Terraform 
# to recognize the change and redeploy the Lambda function. 
#
# To view more detailed documentation and usage instructions, use the `make help` command.
#
# The module includes the following steps:
#
# 1. Calculate a hash of the source code directory.
# 2. Install dependencies based on the requirements.txt file.
# 3. Package the source code and dependencies into a ZIP file.
# 4. Deploy the Lambda function using the generated ZIP file.
# 5. Set up IAM roles and policies to grant the Lambda necessary permissions.
#
# --------------------------------------
# Module Structure Diagram (Compact)
# --------------------------------------

# ┌──────────────────────────────────────────────────────────────────────────┐
# │ data "archive_file" "source_code_hash"                                    │
# │ ─ Calculate hash of source directory                                      │
# └──────────────┬───────────────────────────────────────────────────────────┘
#                │
#                ▼
# ┌──────────────────────────────────────────────────────────────────────────┐
# │ resource "null_resource" "install_dependencies"                           │
# │ ─ Install dependencies if source code hash changes                        │
# └──────────────┬───────────────────────────────────────────────────────────┘
#                │
#                ▼
# ┌──────────────────────────────────────────────────────────────────────────┐
# │ data "archive_file" "lambda_package"                                      │
# │ ─ Package source code & dependencies into ZIP                             │
# └──────────────┬───────────────────────────────────────────────────────────┘
#                │
#                ▼
# ┌──────────────────────────────────────────────────────────────────────────┐
# │ resource "aws_lambda_function" "lambda_function"                          │
# │ ─ Deploy Lambda function using the ZIP file                               │
# └──────────────┬───────────────────────────────────────────────────────────┘
#                │
#                ▼
# ┌──────────────────────────────────────────────────────────────────────────┐
# │ resource "aws_iam_role" "lambda_role"                                     │
# │ ─ Define IAM Role for Lambda                                              │
# │                                                                            │
# │ data "aws_iam_policy_document" "lambda_assume_role_policy"                 │
# │ ─ Define IAM assume role policy                                            │
# │                                                                            │
# │ data "aws_iam_policy_document" "lambda_policy_document"                    │
# │ ─ Define IAM policies for permissions                                      │
# └──────────────────────────────────────────────────────────────────────────┘

# --------------------------------------
# Terraform Code with Roles and Permissions
# --------------------------------------

# Step 1: Calculate hash of the source directory
data "archive_file" "source_code_hash" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_code"
  output_path = "/tmp/temp.zip" # Temporary file, we just need the hash
}

# Step 2: Install dependencies if source code changes
resource "null_resource" "install_dependencies" {
  triggers = {
    source_code_hash = data.archive_file.source_code_hash.output_base64sha256
  }
  provisioner "local-exec" {
    command = "pip install -r ${path.module}/requirements.txt -t ${path.module}/lambda_code/"
  }
}

# Step 3: Package source code and dependencies into a ZIP file
data "archive_file" "lambda_package" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_code"
  output_path = "${path.module}/lambda_code.zip"
  excludes    = [".touch", "Makefile"] # Exclude .touch and Makefile from the package
  depends_on  = [null_resource.install_dependencies]
}

# Step 4: Deploy Lambda function using the generated ZIP file
resource "aws_lambda_function" "lambda_function" {
  function_name    = "example-lambda-function"
  role             = aws_iam_role.lambda_role.arn
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  runtime = "python3.8"
  handler = "handler.lambda_handler"
  timeout = 60
}

# Step 5: Define IAM Role and attach policies for Lambda
resource "aws_iam_role" "lambda_role" {
  name                  = "example-lambda-role"
  force_detach_policies = false
  max_session_duration  = 3600
  assume_role_policy    = data.aws_iam_policy_document.lambda_assume_role_policy.json
  inline_policy {
    name   = "lambda-permissions"
    policy = data.aws_iam_policy_document.lambda_policy_document.json
  }
}

# IAM Assume Role Policy for Lambda
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# IAM Policy Document for Lambda permissions
data "aws_iam_policy_document" "lambda_policy_document" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "cloudwatch:*",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:CreateLogGroup",
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["arn:aws:s3:::example-bucket", "arn:aws:s3:::example-bucket/*"]
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["arn:aws:secretsmanager:region:account-id:secret:example-secret"]
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
    ]
  }

  statement {
    sid       = "InvokePermission"
    effect    = "Allow"
    resources = ["*"]
    actions   = ["lambda:InvokeFunction"]
  }
}
