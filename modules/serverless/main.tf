# Serverless Module - S3 and Lambda

################################################################################
# S3 Bucket for Assets
################################################################################

resource "aws_s3_bucket" "assets" {
  bucket = var.assets_bucket_name

  tags = merge(
    var.tags,
    {
      Name        = var.assets_bucket_name
      Description = "Bucket for InnovateMart product images and assets"
    }
  )
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

################################################################################
# Lambda Function IAM Role
################################################################################

resource "aws_iam_role" "lambda" {
  name = "${var.lambda_function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda.name
}

resource "aws_iam_role_policy" "lambda_s3" {
  name = "${var.lambda_function_name}-s3-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.assets.arn,
          "${aws_s3_bucket.assets.arn}/*"
        ]
      }
    ]
  })
}

################################################################################
# Lambda Function
################################################################################

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${var.lambda_source_dir}/asset_processor.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "asset_processor" {
  filename         = data.archive_file.lambda.output_path
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda.arn
  handler          = "asset_processor.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.assets.id
    }
  }

  tags = merge(
    var.tags,
    {
      Name        = var.lambda_function_name
      Description = "Processes uploaded assets from S3"
    }
  )
}

################################################################################
# S3 Bucket Notification to Lambda
################################################################################

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.asset_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.assets.arn
}

resource "aws_s3_bucket_notification" "assets" {
  bucket = aws_s3_bucket.assets.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.asset_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

################################################################################
# CloudWatch Log Group for Lambda
################################################################################

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 7

  tags = var.tags
}