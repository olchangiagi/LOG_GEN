# kinesis -> firehose -> s3
resource "aws_kinesis_firehose_delivery_stream" "logs" {
  # 이름
  name = local.firehose_name
  destination = "extended_s3"
  
  # 입력소스 (kinesis, 역할 설정)
  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.logs.arn
    role_arn = aws_iam_role.firehose.arn
  }
  
  # 출력대상
  extended_s3_configuration {
    # 버킷
    bucket_arn = aws_s3_bucket.data
    # 역할
    role_arn = aws_iam_role.firehose.arn

    # 버퍼 관련 용량, 시간 설정
    buffering_size = var.firehose_buffer_size # 1Mib
    buffering_interval = var.firehose_buffer_interval # 60초

    # 데이터를 모아둔 상태9버퍼링) 에서 기록 -> 포멧
    # 데이터 레코드 압축
    compression_format = "UNCOMPRESSED" # 1차는 원본 지정, 활성화되지 않음
    # compression_format = "GZIP" # GZIP으로 압축

    # s3 버킷 및 s3 오류 출력 접두사 시간대
    custom_time_zone = "Asia/Seoul"

    # 아래처럼 구성 -> partition pruning -> Athena/opensearch/Glue/Spark 등 column 기반으로 데이터 추출할 때 유용
    # s3 버킷 접두사
    # bronze/year = 2026/month=08/day=20/hour=11...처럼 파티션이 나눠짐
    prefix = "bronze/year=!{timestamp:yyyy}/month=!{timestamp:dd}/hour=!{timestamp:HH}/"

    # s3 버킷 오류 출력 접두사
    # 현재 에러 단독 구성, bronze/silver/gold 등 계층 구분을 하지 않음 -> 필요시 구성 
    error_output_prefix = "error/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:dd}/hour=!{timestamp:HH}/"
  }

  # 의존성
  depends_on = [
    # 해당 정책 입/출력 엑세스 권한 생성 후 firehose 생성되도록 설정
    aws_iam_role_policy.firehose
  ]
}