# 개요
- Bronze (raw data 저장, 모든 단위 중요)
    - log generator -> kinesis -> firehose(1Mib/60s) -> s3 bronze (raw data, GZIP)
- Silver (raw data -> 정제/전처리 등 데이터 조작 -> 저장)
    - step 1
        - log generator -> kinesis(input) -> Flink(java, python, pom.xml, maven) -> kinesis(output) ->firehose -> s3 silver
    - step 2
         - log generator -> kinesis(input) -> lambda -> kinesis(output) ->firehose -> s3 silver