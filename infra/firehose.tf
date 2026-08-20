# kinesis -> firehose -> s3
resource "aws_kinesis_firehose_delivery_stream" "logs" {
  # 이름
  name = local.firehose_name
  destination = "extended_s3"
  
  # 입력소스
  kinesis_source_configuration {
    
  }
  
  # 출력대상
  extended_s3_configuration {
    
  }

  # 의존성
  depends_on = [
    # 해당 정책 입/출력 엑세스 권한 생성 후 firehose 생성되도록 설정
    aws_iam_role_policy.firehose
  ]
}