'''
- silver-gold 파이프라인
    silver kinesis -> 
    lambda 함수 -> 100건당 함수가 호출 -> 지연에 대한 집계처리 -> 
    gold kinesis -> firehose (64MB 혹은 1분) 출력 -> parquet 압축(glue 테이블의 스키마 활용) -> s3 gold 버킷에 기록

- gold 데이터는 64MB 혹은 1분 단위로 지연에 대한 집게처리가 모여서 구성: 데이터마트에 준해서 구성
- 추후 대시보드는 gold를 바라보고 1분 단위 혹은 64MB 단위로 화면을 갱신하며 실시간 현황 표현
  (실제 데이터보다 n분(얼마 단위로 설계 -> 파이프라인 구성 영향) 정도 늦게 반영)

- lambda 기본 파이썬만 구성되어 있음 -> 추가 라이브러리 사용 -> zip으로 같이 묶어서 배포(번잡함)
- 아래 구성 코드는 순수 파이썬 + 기본 라이브러리
'''


from __future__ import annotations

import base64
import json
import os
from collections import defaultdict
from datetime import datetime, timezone
from typing import Any

import boto3

# gold kinesis의 이름 - 테라폼에서 환경변수로 전달
GOLD_STREAM_NAME = os.environ["GOLD_STREAM_NAME"]
# 기본 리전까지 추가하여 전달
AWS_REGION = os.environ.get("AWS_REGION_NAME") or os.environ.get(
    "AWS_REGION", "ap-northeast-2"
)

GOLD_SCHEMA_VERSION = "1.0"

kinesis = boto3.client("kinesis", region_name=AWS_REGION)


def _decode_kinesis_record(record: dict[str, Any]) -> dict[str, Any]:
    '''
    람다에 전달된 event(데이터 1개)를 json 객체로 복원(역직렬화)
    '''
    encoded = record["kinesis"]["data"]

    payload = base64.b64decode(encoded).decode("utf-8")

    value = json.loads(payload)

    if not isinstance(value, dict):
        # 형식에 문제가 발생 -> 오류 반환
        raise ValueError("Silver payload must be a JSON object.")
    
    # dict 객체 반환 
    return value


def _to_latency(value: Any) -> float | None:
    if isinstance(value, bool):
        return None

    if isinstance(value, (int, float)):
        result = float(value)

    elif isinstance(value, str):
        try:
            result = float(value.strip())
        except ValueError:
            return None

    else:
        return None

    if result < 0:
        return None

    return result


def _is_success(event: dict[str, Any]) -> bool:
    response = event.get("response")

    if not isinstance(response, dict):
        return False

    try:
        status_code = int(response.get("status_code"))
    except (TypeError, ValueError):
        return False

    return status_code < 400


def _aggregate(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    '''
    silver 이벤트(데이터)를 domain 단위로 Gold 지표에 집계하여 데이터 구성
    비즈니스 목적에 맞게 데이터 가공
    '''
    # 도메인별 기본 틀을 제공하는 형태의 변수 정의
    groups: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "event_count": 0,
            "success_count": 0,
            "error_count": 0,
            "latencies": [],
        }
    )

    for event in records:
        # 도메인 획득 -> 공백 제거, 소문자 정제 과정
        domain = str(event.get("domain") or "unknown").strip().lower()

        group = groups[domain]

        group["event_count"] += 1

        if _is_success(event):
            group["success_count"] += 1
        else:
            group["error_count"] += 1

        response = event.get("response")

        if isinstance(response, dict):
            latency = _to_latency(response.get("latency_ms"))

            if latency is not None:
                group["latencies"].append(latency)

    processed_at = datetime.now(timezone.utc).isoformat()

    output: list[dict[str, Any]] = []
    # 도메인별로 세팅 -> 현재는 이커머스만 존재
    for domain, group in sorted(groups.items()):
        # 응답 시간 집계 게산
        latencies = group["latencies"]

        avg_latency = (
            round(sum(latencies) / len(latencies), 2)
            if latencies
            else 0.0
        )

        min_latency = int(min(latencies)) if latencies else 0
        max_latency = int(max(latencies)) if latencies else 0

        # 결과 판단
        if group["error_count"] == 0:
            result = "success"
        elif group["success_count"] == 0:
            result = "error"
        else:
            result = "mixed"

        # Gold에 삽입되는 최종 데이터 형태 -> Glue의 테이블로 스키마를 설계해야 함. parquet 처리
        output.append(
            {
                "processed_at": processed_at,               # Gold용 데이터로 처리 시간
                "domain": domain,                           # 도메인
                "event_count": group["event_count"],        #이벤트 개수
                "success_count": group["success_count"],    # 성공 개수
                "error_count": group["error_count"],        # 실패(오류) 개수
                "avg_latency_ms": avg_latency,              # 평균 응답 시간
                "min_latency_ms": min_latency,              # 최소 응답 시간
                "max_latency_ms": max_latency,              # 최대 응답 시간
                "result": result,                           # 데이터 성공 여부
                "gold_schema_version": GOLD_SCHEMA_VERSION, # 스키마 관리 버전
            }
        )

    return output


def _put_gold_records(records: list[dict[str, Any]]) -> None:
    '''
    최종 가공된 데이터를 gold layer로 보내기 위해, gold kinesis로 전송
    '''
    # 내용이 비어있으면 컷
    if not records:
        return

    # kinesis에 전송 가능한 형태로 가공
    request_records = [
        # 리스트 컴프리 핸선으로 [ {}, {}, {}, ... ]
        {
            "Data": (
                # 직렬화 처리 dict -> 문자열 변환
                json.dumps(
                    record,
                    ensure_ascii=False,     # 아스키가 아니먄 한글, 기호 그대로 표기
                    separators=(",", ":"),  # 구분자 변경
                )
                # jsonl을 고려하여 줄바꿈 추가
                + "\n"
            ).encode("utf-8"),
            # 같은 도메인을 가진 데이터는 같은 shard로 전달할 수 있게 파티션화
            # event_type을 사용 -> 같은 이벤트는 같은 shard로 전달 -> 확장 가능
            "PartitionKey": record["domain"],
        }
        for record in records
    ]

    # 전송
    response = kinesis.put_records(
        StreamName=GOLD_STREAM_NAME,
        Records=request_records,
    )

    # 전송시 실패하면 오류 발생 -> 로그에 기록됨
    if response.get("FailedRecordCount", 0):
        raise RuntimeError(
            f"Failed to write "
            f"{response['FailedRecordCount']} Gold record(s) to Kinesis."
        )


# 엔트리 포인트
def lambda_handler(
    event: dict[str, Any],
    context: Any,
) -> dict[str, Any]:
    # 정상적으로 처리된 silver 데이터 저장 공간
    silver_events: list[dict[str, Any]] = []
    # 응답 실패용 저장 공간
    batch_failures: list[dict[str, str]] = []
    # event는 kinesis로 부터 흘러들어오는 각각의 데이터를 의미함

    # 이벤트(데이터 1개 획득) -> n번 반복 -> [ {}, {}, {}, ...]
    for record in event.get("Records", []):
        try:
            # 정상 데이터로 판단하고 추가 -> 오류 발생 -> 예외 처리 -> batch_failures 저장
            silver_events.append(
                _decode_kinesis_record(record)
            )
        
        except Exception as exc:
            # kinesis가 전달한 데이터의 sequenceNumber만 획득
            sequence_number = (
                record.get("kinesis", {})
                .get("sequenceNumber")
            )

            if sequence_number:
                # 해당 시퀀스 번호가 있으면 저장 -> kinesis에서 조회 가능
                batch_failures.append(
                    {
                        "itemIdentifier": sequence_number
                    }
                )
            # 로그 -> CloudWatch에서 조회 가능
            print(
                f"[WARN] Failed to decode Silver record: {exc}"
            )
    # 정상 데이터만 대상으로 집계 (gold에서 최종 데이터 형태가 집계/통계형) 처리
    gold_records = _aggregate(silver_events)

    # 최종 데이터(silver 데이터를 비즈니스 목적에 맞게 처리)를 gold kinesis 전송
    _put_gold_records(gold_records)

    # 로그
    print(
        json.dumps(
            {
                "silver_record_count": len(silver_events),
                "gold_record_count": len(gold_records),
                "failed_record_count": len(batch_failures),
            },
            separators=(",", ":"),
        )
    )

    # 반환
    return {
        "batchItemFailures": batch_failures
    }