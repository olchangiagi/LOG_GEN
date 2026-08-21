# Managed Service for Apache Flink (관리형 서비스 형태의 Flink)의 IAM
data "aws_iam_policy_document" "flink_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["kinesisanalytics.amazonaws.com"]
    }
  }
}
# 2. 해당 Role 정의(생성)
resource "aws_iam_role" "flink" {
  name               = "${var.project_name}-flink-role"
  assume_role_policy = data.aws_iam_policy_document.flink_assume.json
}

# 3. 추가로 정책을 반영 (정책 조회 -> 정책 role 연결)
# 브론즈 kinesis 읽기 (입력, inputstream)
# 실버 kinesis 쓰기 (출력, outputstream)
# s3에 flink의 애플리케이션 zip 파일 읽기 -> 실행할 수 있음
# CloudWatch Logs에 로그 기록
data "aws_iam_policy_document" "firehose_s3" {
  # kinesis 읽기 권한 관련
  statement {
    sid    = "ReadBronzeKinesis"
    effect = "Allow"
    actions = [
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:GetShardIterator",
      "kinesis:GetRecords",
      "kinesis:ListShards"
    ]
    resources = [
      aws_kinesis_stream.logs.arn
    ]
  }
  statement {
    sid    = "WriteSilverKinesis"
    effect = "Allow"
    actions = [
      "kinesis:DescribeStream",
      "kinesis:GetShardIterator",
      "kinesis:GetRecords",
      "kinesis:ListShards"
    ]
    resources = [
      aws_kinesis_stream.logs.arn
    ]
  }
  statement {
    sid    = "ReadFlinkCode"
    effect = "Allow"
    actions = [
      "kinesis:DescribeStream",
      "kinesis:GetShardIterator",
      "kinesis:GetRecords",
      "kinesis:ListShards"
    ]
    resources = [
      aws_kinesis_stream.logs.arn
    ]
  }
  statement {
    sid    = "DescribeFlinklog"
    effect = "Allow"
    actions = [
      "kinesis:DescribeStream",
      "kinesis:GetShardIterator",
      "kinesis:GetRecords",
      "kinesis:ListShards"
    ]
    resources = [
      aws_kinesis_stream.logs.arn
    ]
  }
}


# firehose_s3를 통해서 조회한 권한을 aws_iam_role.firehose 에 부여
resource "aws_iam_role_policy" "firehose" {
  name   = "${var.project_name}-firehose-s3-policy"
  role   = aws_iam_role.firehose.id
  policy = data.aws_iam_policy_document.firehose_s3.json
}