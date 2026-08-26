# silver kinesis -> lambda -> gold kinesis -> firehose -> s3 gold 
# 필요한 모든 리소스, 권한 등 하나의 tf에서 구성

# variables
variable "gold_kinesis_shard_count" {
  description = "KDS's shard count"
  type        = number
  default     = 1
}

variable "gold_kinesis_retention_hour" {
  description = "KDS's retention period in hours"
  type        = number
  default     = 24
}

# locals
locals {
    # Gold Kinesis 리소스 이름
    gold_kinesis_stream_name = "${var.project_name}-gold-kinesis"

    # Gold Firehose 리소스 이름
    gold_firehose_name = "${var.project_name}-gold-firehose"

    # Silver 데이터 -> Gold용을 구성 (집계등) 처리하는 lambda 함수명
    gold_lambda_name = "${var.project_name}-silver-to-gold"

    # 람다 함수 배포용 zip 경로 (terraform 업로드 처리)
    gold_lambda_zip = "${path.module}/../lambda/gold/gold-lambda.zip"
}

# kinesis 
resource "aws_kinesis_stream" "gold" {
  name             = local.gold_kinesis_stream_name
  shard_count      = var.gold_kinesis_shard_count     
  retention_period = var.gold_kinesis_retention_hour  

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = {
    DataLayer = "silver"
  }
}
# iam-role
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-gold-lambda-role"
  # 위에서 만든 신뢰정책 반영하여 role 구성
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}
data "aws_iam_policy_document" "lambda" {
  # 1. CloudWatch Logs에 기록
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["arn:aws:logs:${var.aws_region}:*:*"]
  }
  # 2. kinesis 기본 필수 권한 (silver kinesis에서 데이터를 )
  statement {
    effect = "Allow"

    actions = [
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
      "kinesis:ListShards",
      "kinesis:ListStreams"
    ]

    resources = [aws_kinesis_stream.silver.arn]
  }
  # 3. kinesis 데이터 기록(집계 결과 전송)
  statement {
    effect = "Allow"

    actions = [
      "kinesis:PutRecord",
      "kinesis:PutRecords"
    ]

    resources = [aws_kinesis_stream.gold.arn]
  }
}
# 기존 role에 새로운 정책(여러 권한 조합)을 부여
resource "aws_iam_role_policy" "lambda" {
  name   = "${var.project_name}-gold-lambda-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda.json
}


# Lambda
resource "aws_lambda_function" "silver_to_gold" {
  # 함수이름
  function_name = local.gold_lambda_name
  # 역활
  role = aws_iam_role.lambda.arn
  # 함수의 엔트리 포인트 -> 어떤 모듈의 어떤 함수를 호출하여 처리하는가
  handler = "main.lambda_handler"
  # 파이썬 작동 -> 서버리스 -> 환경 구성되어 있어야 함
  runtime = "python3.12"
  # 가동시 가용 메모리
  memory_size = 256 # MB
  # 처리 시간 timeout 설정
  timeout = 30
  # 배포한 ZIP 경로
  filename = local.gold_lambda_zip
  # 업데이트 감지
  source_code_hash = filebase64sha256(local.gold_lambda_zip)
  # 환경변수 -> lambda 함수 작동시 외부에서 전달하는 값
  environment {
    variables = {
      GOLD_STREAM_NAME = aws_kinesis_stream.gold.name
      AWS_REGION_NAME = var.aws_region
    }
  }
  # 의존성
  depends_on = [ aws_iam_role_policy.lambda ]
  # 태그
  tags = {
    DataLayer = "gold"
    Processor = "lambda"
  }
}

# silver kinesis -> lambda 연결

# firehose iam role 

# gold firehose










# 편의상 실시간성을 고려하여 구성
# silver -> lambda -> gold kinesis -> firehose -> glue schema -> parquet(SNAPPY) -> s3 gold/

# 파이썬 파일 -> ZIP 패키징 관련
# lambda python 소스코드를 AWS lambda에 배포할 ZIP 파일에 포함하여 자동 생성 
# data "archive_file" "gold_lambda" {
#    type = "zip"
#    source_file = "${path.module}/.../lambda/lambda_function.py"
#    output_path = "${path.module}/.../lambda/gold-lambda.zip"
# }