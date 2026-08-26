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
로그 제너레이터 (ECR, ECS, Fargate)
    ↓
 Firehose
    ↓
Bronze
 JSON/GZIP
    ↓
 Kinesis
    ↓
  Flink -> 정제(고비용/고가용성) -> SQL로 구성(Insert를 통해 silver)
    ↓
Silver Kinesis
    │
    ├── 기존 Firehose
    │       ↓
    │   Parquet -> Glue / Model catalog -> Database -> table
    │       ↓
    │   S3 silver/ -> Airflow 배치 프로세싱 -> Athena 이용 SQL -> 데일리 레포트 구성(Gold)
    │
    └── [추가] Lambda : 의도적으로 Silver Kinesis에서 이미 정제된 데이터를 실시간으로 받아서 실시간 파이프라인 흐름 유지
              ↓
         비즈니스 가공 (분석용 데이터로 구성, 집계, 통계,...) -> pandas/polars/spark(무거움) or 단순 구성 처리 
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
         Glue / Athena -> 작업 그룹 구성 -> 대시보드/서비스에서 SQL로 데이터 획득하여 서비스 활용
```

# 데이터 변화 확인
- 브론즈 : 원본 raw 데이터 보존
```
{
  "event_id": "evt_...",
  "domain": "ecommerce",
  "event_type": "payment_completed",
  "occurred_at": "2026-08-25T18:35:00.123+09:00",

  "request": {
    "method": "POST",
    "path": "/api/payments"
  },

  "response": {
    "status_code": 200,
    "latency_ms": 418
  },

  "data": {
    "user_id": "usr_483921",
    "session_id": "af20d91c84d24978ac31",
    "product_id": "prd_38142",
    "category": "electronics",
    "quantity": 2,
    "unit_price": 45900,
    "currency": "KRW",
    "campaign": "summer_sale",
    "order_id": "ord_38ab72cf219a4182",
    "total_amount": 91800,
    "payment_method": "card",
    "payment_result": "approved"
  }
}
```
- 브론즈 : 오염 데이터(보관) -> 후속 처리 (원인 규명)
- 임의로 구성한 것이므로 -> 시나리오 구성, 실제에 대해 조사 후 반영
```
{
  "event_id": "evt_...",
  "domain": "ecommerce",
  "event_type": "payment_completed",
  "occurred_at": "2026-08-25T18:35:01.382+09:00",

  "request": {
    "method": "POST",
    "path": "/api/payments"
  },

  "response": {
    "status_code": 200,
    "latency_ms": 391
  },

  "data": {
    "user_id": "usr_738251",
    "session_id": "98dc15b31d2a4017a832",
    "product_id": "prd_71632",
    "category": "food",

    "quantity": 1000000, <- 주문 수량이 백만개로 극단적 이상치로 설정, 실제는 1

    "unit_price": 18900,
    "currency": "KRW",
    "campaign": null,
    "order_id": "ord_82ae31c20bb84081",
    "total_amount": 18900,
    "payment_method": "easy_pay",
    "payment_result": "approved"
  },

  "_simulation": {
    "is_corrupted": true,
    "corruption_type": "numeric_outlier"
  }
}
```
- 실버
- flink를 통해 클린 작업 진행(5가지 유형만), 전처리등 작업 진행
- data 항목에 모든 도메인에 대해 커버 가능하도록 컬럼 추가, 해당 도메인이 아니면 null 세팅(슈퍼셋)
- _silver 추가 -> 어떤 단계에서 어떤 프로세스를 사용(flink), 언제 정제/전처리등을 진행하였는지 시간 기록
- 로그 발생 시간부터 각 단계별 처리시간 비교 -> 지연, 전체 처리 시간등 모니터링, 분석 처리 가능
```
{
  "schema_version": "1.0",
  "record_type": "application_log",
  "event_id": "befbbe74-c142-475e-a26b-2be5d175b273",
  "trace_id": "aff1b4e4d10a4a589873baa3395ddba4",
  "run_id": "loggen-1695217703-16184",

  "occurred_at": "2026-08-25T14:41:53.280+09:00",
  "generated_at_utc": "2026-08-25T05:41:53.280+00:00",

  "domain": "ecommerce",
  "event_type": "product_view",

  "service": {
    "name": "commerce-api",
    "environment": "simulation",
    "instance_id": "sim-07"
  },

  "client": {
    "ip": "128.189.114.29",
    "user_agent": "Mozilla/5.0 Chrome/151.0 Android/15",
    "device_id": "973ee19556c34e20"
  },

  "request": {
    "method": "GET",
    "path": "/api/products/prd_31528",
    "request_bytes": 147
  },

  "response": {
    "status_code": 200,
    "latency_ms": 57,
    "response_bytes": 2204
  },

  "data": {
    "user_id": "usr_366134",
    "session_id": "0119d7b2a06f401ab8c3",
    "product_id": "prd_31528",
    "category": "fashion",
    "quantity": 1,
    "unit_price": 297200,
    "currency": "KRW",

    "campaign": null,
    "keyword": null,
    "result_count": null,
    "order_id": null,
    "total_amount": null,
    "payment_method": null,
    "payment_result": null
  },

  "_silver": {
    "layer": "silver",
    "processor": "apache-flink",
    "schema_version": "1.0",
    "processed_at": "2026-08-25T05:41:54.644721+00:00"
  }
}
```
- 골드: 최종 목표 데이터의 형태
- 분석용 데이터 생성 목표
    - 집계, 통계 등 분석에 필요한 데이터 형태를 구성
    - lambda에서 아래처럼 데이터를 구성 or 아래처럼 데이터를 확보할 수 있게 전 단계 구성
        - Athena를 통해 최종 집계 등 데이터 조회
```
{
  "domain": "ecommerce",
  "category": "electronics",

  "action_count": 1523,
  "total_revenue": 28452000,
  "avg_order": 18681,
  "conversion_rate": 0.087
}
```

# 인프라 및 코드 구성
```
silver-to-gold-lambda/
├─ infra/ 
│  ├─ gold-lambda.tf    : lambda 사용에 관련된 모든 내용 총합 세팅(로컬, 리소스, iam-role등)
│  ├─ glue-gold.tf      : parquet 저장에 따른 glue 설정
│  └─ outputs-gold.tf   : 출력값(신규 세팅)
│
├─ lambda/                  : 신규 폴더
│  └─ gold/     
│     ├─ main.py            : 처리 함수
│     └─ gold-lambda.zip    : lambda에 배포할 압축 파일
│
├─ scripts/
│  ├─ build-gold-lambda.bat : 빌드
│  └─ build-gold-lambda.sh  : 빌드
```
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

```

# 인프라 구성
- gold-lambda.tf

