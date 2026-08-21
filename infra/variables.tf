variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "리소스 이름에 사용할 프로젝트명"
  type        = string
  default     = "de-ai-08-loggen"
}

variable "vpc_cidr" {
  description = "VPC CIDR, fargate 전용"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public Subnet CIDR 목록, fargate task 작동시 매번 다른 가용영역 사용"
  type        = list(string)
  # AZ 가용영역을 2개 사용 염두
  default = ["10.20.1.0/24", "10.20.2.0/24"]

  # 유효성 검사
  validation {
    # 최소 1개이상이면 정상
    condition     = length(var.public_subnet_cidrs) >= 1
    error_message = "최소 1개 퍼블릭 서브넷 CIDR 필수임"
  }
}

# fargate task CPU
variable "task_cpu" {
  description = "cpu unit => 512 == 0.5 vCPU"
  type        = number
  default     = 512
}

# fargate task MEMORY
variable "task_memory" {
  description = "memory Mib"
  type        = number
  default     = 1024
}

# cloudwatch log 보관 일수
variable "log_retention_days" {
  description = "cloudwatch log retention period"
  type        = number
  default     = 7
}

# ECS TASK가 ECR 이미지 사용시 태그 -> latest
variable "image_tag" {
  description = "task가 정의될때 참고하는 태그명, 가징 최신"
  type        = string
  default     = "latest"
}

# [브론즈 추가]
# Kinesis Data Streams : KDS
# 성능 영향 -> shard 개수, 데이터 보관 기간(retention)
# 프로비저닝 방식으로 구성한다 -> 샤드수 직접 지정 <-> 온디맨드 (자율 구성)
variable "kinesis_shard_count" {
  description = "KDS's shard count"
  type        = number
  default     = 1
}

# 전송되지 않은 데이터는 하루만 보관
variable "kinesis_retention_hour" {
  description = "KDS's retention period in hours"
  type        = number
  default     = 24
}

# Amazon Data Firehose : ADF
# 1~128MiB, 5MiB 권장
variable "firehose_buffer_size" {
  description = "해당 크기만큼 데이터가 쌓이면 전송"
  type        = number
  default     = 1
}

# 0~900초 지원, 300초 권장
variable "firehose_buffer_interval" {
  description = "해당 시간만큼 데이터가 쌓으면 강제 전송"
  type        = number
  default     = 60
}

# [실버 추가]
# silver layer에서 출력용 샤드 수
variable "silver_kinesis_shard_count" {
  description = "KDS's shard count"
  type        = number
  default     = 1
}

# kinesis에서 미전송된 데이터 보관 기간
variable "silver_kinesis_retention_hour" {
  description = "KDS's retention period in hours"
  type        = number
  default     = 24
}

# PyFlink 버전(런타임 환경의 버전) 1.20 사용
variable "flink_runtime_enviroment" {
  description = "Managed Service for Apache Flink의 런타임 환경 버전"
  type        = string
  default     = "FLINK-1_20"
}

# Flink 어플리케이션 병렬 구성 수
# 현재는 1이 기본값, 최소 실행 단위
variable "flink_parallelism" {
  description = "Initial Flink application parallelism"
  type        = number
  default     = 1
}

# KPU(kinesis Processing Unit) 하나당 Parallel task 수 설정
# 기본 컴퓨팅의 과금 단위
variable "flink_parallelism_per_kpu" {
  description = "Flink parallel tasks per KPU"
  type        = number
  default     = 1
}

# true: 인프라 적용되면 -> 실행
# false: 실제 사용시 적용
variable "flink_start_application" {
  description = "Whether Terraform should start the Managed Flink application"
  type        = bool
  default     = true
}

# Flink를 가동한 후 입력쪽(브론즈향) kinesis에서 데이터 읽을 때 어디서 부터 처리할 것인가? 설정
# 데이터는 게속해서 전송중 -> 추후 Flink 가동 -> 가동 전에 도달한 데이터도 처리할 것인가? flink 가동 이후 도착한 데이터만 처리할 것인가?
# LATEST: Flink 가동 이후 도착한 데이터만 처리
# TRIM_HORIZON: Flink 가동 이전에 도착한 데이터도 처리
variable "flink_source_init_position" {
  description = "flink가 데이터 처리시 입력원쪽의 어디서부터 처리할 것인가 설정"
  type        = string
  default     = "LATEST"

  # 변수의 값으로 올 수 있는 내용들을 제약
  validation {
    # 오직 2가지만 허가됨
    condition = contains([
      "LATEST",
      "TRIM_HORIZON"
    ], var.flink_source_init_position)
    error_message = "flink_source_init_position is only LATEST or TRIM_HORIZON"
  }
}