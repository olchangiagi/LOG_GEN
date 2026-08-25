# 목표
- 실버에서 골드로 파이프라인 구성중 기점으로 lambda 사용
    - 실시간 관점에서는 flink를 거치는 적절함.
- 구성 조합
    - Bronze -> flink/lambda -> silver : 신뢰할 수 있는 데이터를 필터링/구성
        - 데이터 클리닝 작업 -> 레코드 단위로 stream processing 처리(flink 관점)
    - Silver -> flink/lambda -> Gold : 데이터를 사용할 수 있게 구성
        - 비즈니스 목적에 맞게 변환 처리
            - flink: 실시간 처리
            - lambda: 이벤트 드라이브 처리 (실습상 s3에 업로드 이벤트 등 활용, silver kinesis에서 lambda 로 바로 전송(실시간성을 살리는 컨셉))

# 목표 시스템
```
Bronze
 JSON/GZIP
    ↓
 Kinesis
    ↓
  Flink
    ↓
Silver Kinesis
    │
    ├── 기존 Firehose
    │       ↓
    │   Parquet
    │       ↓
    │   S3 silver/
    │
    └── [추가] Lambda : 의도적으로 Silver Kinesis에서 이미 정제된 데이터를 실시간으로 받아서 실시간 파이프라인 흐름 유지
              ↓
         비즈니스 가공 
              ↓
         Gold Kinesis
              ↓
          Firehose
              ↓
       Glue Schema 참조
              ↓
       Parquet + SNAPPY
              ↓
          S3 gold/
              ↓
         Glue / Athena
```

# 인프라 및 코드 구성
- lambda/lambda_function.py 추가
- infra/gold-lambda.py 추가
- infra/glue-gold.py 추가
- infra/outputs.tf 내용 추가
- lambda 서비스에 배포 작업(필요하면 추가 파일 등 고려)

# lambda 
- 서버에 대한 걱정 없이 코드 실행(함수 단위)
    - 파이썬/노드/자바 등 언어에 대한 세팅 x
    - 최소 라이브러리만 지원 -> 필요시 서드 파트 라이브러리 업로드 필요
- 서버리스
- 이벤트 드라이븐 형태로 작동
    - s3에 무언가 업로드(소카 서비스 이용 후 차량 촬영 후 업로드) -> 트리거 작동 -> lambda 작동 -> 사진 전처리/분석 행위 -> 결과를 SQS 전송 -> gold 도달 -> 고객 앱으로 전달

# 람다 코드 작성
```
/
L lambda
    L lambda function.py
```
