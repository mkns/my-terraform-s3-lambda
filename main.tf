terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.68.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = "~> 1.0"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "lambda_bucket" {
    bucket = "mkns-20211204-terraform-s3-lambda"

  acl           = "private"
  force_destroy = true
}

resource "aws_s3_bucket" "input_bucket" {
    bucket = "mkns-20211204-terraform-s3-lambda-input"

  acl           = "private"
  force_destroy = true
}

data "archive_file" "lambda_script" {
  type = "zip"

  source_dir  = "${path.module}/script"
  output_path = "${path.module}/script.zip"
}

resource "aws_s3_bucket_object" "lambda_script" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "script.zip"
  source = data.archive_file.lambda_script.output_path

  etag = filemd5(data.archive_file.lambda_script.output_path)
}

resource "aws_lambda_function" "script" {
  function_name = "mkns20211204_trigger"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_bucket_object.lambda_script.key

  runtime = "python3.9"
  handler = "mkns-20211204.lambda_handler"

  source_code_hash = data.archive_file.lambda_script.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_cloudwatch_log_group" "script" {
  name = "/aws/lambda/${aws_lambda_function.script.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
    role       = aws_iam_role.lambda_exec.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "s3_readonly" {
    role       = aws_iam_role.lambda_exec.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.script.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.input_bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.input_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.script.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
    filter_suffix       = ".json"
  }
}
