# 개요
- Bronze (raw data 저장, 모든 단위 중요)
    - log generator -> kinesis -> firehose(1Mib/60s) -> s3 bronze (raw data, GZIP)
- Silver (raw data -> 정제/전처리 등 데이터 조작 -> 저장)
    - Streamming Ingesction -> Streamming Processing + Medalion Architecture
        - log generator -> kinesis(input) -> Flink(java, python, pom.xml, maven) -> kinesis(output) ->firehose -> s3 silver
    - step 2
         - log generator -> kinesis(input) -> lambda -> kinesis(output) ->firehose -> s3 silver

# Flink
- 실시간으로 스트리밍 데이터에서 실행 가능한 분석 정보를 확보
    - 실시간 데이터를 실시간으로 전처리/정제 등 작업 가능 -> 거의 지연이 없음
- 실시간일 필요가 없음 -> Airflow, Step Function(AWS) 이용하여 Batch Processing 처리
- Silver 단계로 저장하는 방법
    - 실시간 -> Flink, lambda
    - 배치 -> Airflow, Step Function