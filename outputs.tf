output "lambda_bucket_name" {
  description = "Name of the S3 bucket used to store function code"
  value = aws_s3_bucket.lambda_bucket.id
}

output "input_bucket_name" {
  description = "Name of the S3 bucket where the input files go"
  value = aws_s3_bucket.input_bucket.id
}

output "bucket_notification_id" {
  value = aws_s3_bucket_notification.bucket_notification.id
}