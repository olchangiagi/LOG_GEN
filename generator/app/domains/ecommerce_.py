'''
- 도메인: 이커머스
- 이커머스 로그: 상품 조회, 검색, 장바구니, 주문, 결제, ... 관련 업무에 대한 로그 생성
'''
import random # 값을 선택, 생성시 확률적인 정보(선택) 제공하는 도구
from faker import Faker
import uuid
from common import http_status

# 해당 도메인에서 발생 가능한 이벤트 종류 정의
EVENTS = ["product_view", "search", "add_to_cart", "checkout", "order_created", "payment_completed"]
# 가중치를 부여하여 이벤트의 발생 빈도 조절 -> 가중치 -> 인사이트 등 도멩니 분석을 하여 설계 -> 현재는 가정
WEIGHTS = [34, 20, 17, 9, 11, 9]
# 카테고리 정의
CATEGORIES = ["food", "fashion", "beauty", "electronics", "home", "sports"]
# 결제 시제
PAYMENTS = ["card", "bank_transform", "easy_pay", "points"]

def generate(fake:Faker, *, timezone_name:str, environment:str, run_id:str) -> dict:
    # 1. 이벤트 타입 선택
    event_type = random.choices(EVENTS, weights = WEIGHTS, k = 1)[0]
    # 2. 사용자 ID(임의 구성 -> 실제라면 가입한 ID 혹은 내부 관리용 ID를 활용)
    user_id = f"usr_{random.randint(100000, 999999)}" # 중복성을 고려하여 랜덤 활용(uuid x)
    # 3. 요청 흐름을 구분하는 세션 ID(고유함 -> uuid 사용)
    session_id = uuid.uuid4().hex[:20] # 중복되지 않는 해시값 20자리 수 제공
    # 4. product_id: 제품 Id, 중복 가능성 있음
    product_id = f"prd_{random.randint(100000, 999999)}"
    # 5. 제품의 주문 수량, 제품 1개를 주문하는 쪽에 가중치를 높게 구성
    quantity = random.choices([1, 2, 3, 4], weights = [70, 20, 7, 3], k = 1)[0]
    # 6. unit_price
    unit_price = random.randrange(5000, 300000, 100)

    # 이벤트별 요청에 대한 method, URL(API 경로), wldus
    routes = {
        "product_view"      : ("GET", f"/products/{product_id}", 70), # ms
        "search"            : ("GET", f"/api/search", 95),
        "add_to_cart"       : ("GET", f"/api/cart/items", 110),
        "checkout"          : ("GET", f"/api/checkout", 240),
        "order_created"     : ("GET", f"/api/orders", 310),
        "payment_completed ": ("GET", f"/api/payments", 420)
    }
    # 메소드, 경로, 지연시간(중간값)
    method, path, median_latency = routes[event_type]
    # 응답 코드 (400 이하면 모두 성공, 그 이상이면 오류)
    status = http_status(method, success = 0.9722, client_error=0.222)

    # 도메인별 데이터
    data = {
        "user_id" : user_id,
        "session_id" : session_id,
        "product_id" : product_id,
        "category" : random.choices(CATEGORIES),
        "quantity" : quantity,
        "unit_price" : unit_price,
        "currency" : "KRW", # 가격 단가
        "campaign" : random.choices([None, None, None, "summer_sale", "coupon", "winter_sale"])
    }

    # 이벤트 타입별 추가 데이터 구성
    if event_type == "search" :
        data.update({
            "keyword" : fake.word(), # 검색어 페이크
            "result_count" : random.randint(0, 240) # 검색 결과셋 랜덤
        })

    # 주문 이벤트(3개)에서 주문 ID, 금액, 결제 시제
    if event_type in {"checkout", "order_created", "pyament_completed"}:
        data.update({
            "order_id" : f"ord_{uuid.uuid4*().hex[:16]}", # 결제 관리 번호 고유하게 관리
            "total_amount" : unit_price * quantity, # 구매 단가
            "payment_method" : random.choices(PAYMENTS)
        })

    # 결제완료 이벤트 -> 성공/실패
    if event_type == "paymen_completed":
        # 응답코드 기준으로 판정 코드 < 400 -> 정상
        data["payment_result"] = "approved" if status < 400 else random.choices(["timeout", "cancelled"])

    return {
        # 공용 데이터
        "event_type" : event_type,

        "request": {
            "method": method,
            "path" : path,
            #"request_bytes": 237
        },
        "response": {
            "status_code" : 200,
            "latency_ms" : median_latency,
            #"response_byte" : 4084
        },

        # 도메인별 커스텀 데이터
        "data" : {
            "user_id" : user_id,
            "session_id" : session_id,
            "product_id" : product_id,
            "category" : random.choices(CATEGORIES),
            "quantity" : quantity,
            "unit_price" : unit_price,
            "currency" : "KRW", # 가격 단가
            "campaign" : random.choices([None, None, None, "summer_sale", "coupon", "winter_sale"])
        }
    }
