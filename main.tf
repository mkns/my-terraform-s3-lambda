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

// set up the s3 bucket which will hold the lambda
resource "aws_s3_bucket" "lambda_bucket" {
    bucket = "mkns-20211204-terraform-s3-lambda"

  acl           = "private"
  force_destroy = true
}

// put the lambda in a zip file and put it in the s3 bucket
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

// define the lambda resource
resource "aws_lambda_function" "script" {
  function_name = "mkns20211204_trigger"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_bucket_object.lambda_script.key

  runtime = "python3.9"
  handler = "mkns-20211204.lambda_handler"

  source_code_hash = data.archive_file.lambda_script.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

// logging
resource "aws_cloudwatch_log_group" "script" {
  name = "/aws/lambda/${aws_lambda_function.script.function_name}"

  retention_in_days = 30
}

// set up a Role which will run the lambda
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

// this lambda needs 2 separate Policies, just using standard AWS-defined ones
resource "aws_iam_role_policy_attachment" "lambda_policy" {
    role       = aws_iam_role.lambda_exec.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "s3_readonly" {
    role       = aws_iam_role.lambda_exec.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

// create another s3 bucket, this time for our input files to be dropped in
resource "aws_s3_bucket" "input_bucket" {
    bucket = "mkns-20211204-terraform-s3-lambda-input"

  acl           = "private"
  force_destroy = true
}

// set up the notification stuff so when something drops in the input s3 bucket, the lambda is triggered
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

// set up another s3 bucket, this time for output
resource "aws_s3_bucket" "output_bucket" {
    bucket = "mkns-20211204-terraform-s3-lambda-output"

  acl           = "public-read"
  force_destroy = true
}
