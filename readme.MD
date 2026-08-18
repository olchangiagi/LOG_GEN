# 목표
- AWS Fargate를 이용한 로그 생성기
    - AWS Fargate
        - EC2 사용/관리 x
        - ECR에 등록된 이미지를 이용하여 ECS에서 직접 컨테이너 실행 -> `서버리스`로 실행환경을 제공 받고 수행
        - 비용이 가장 저렴함
    - 발생된 데이터
        - 데이터 형태 : 요청 -> 서비스 대응 -> 응답 -> 모두 합친 최종 로그, 서비스 구성x
        - 데이터 저장
            - s3: 다음 챕터에서 확장 활용
            - cloudwatch: aws 로그 저장
            - file
            - 콘솔

# 인프라 구성
- variable.tf   : 리전, 프로젝트명, CPU/Memory 등 정보 기술, 구성 조정
- version.tf    :
- provider.tf   :
- locals.tf     : 공통값 가공, 태그, 전체 프로젝트 프리픽스
- vpc.tf        : 전용 네트워크, VPC, Subnet, IGW, Route table, SG, AZ
- iam.tf        : Fargate가 ECR 이미지를 획득, CloudWatch의 로그기록 -> 권한 부여
- logs.tf       : ECS 컨테이너 내에 (로그 생성기 존재) 발생되는 로그 -> 로그그룹 지정
- ecr.tf        : 로그 생성기 (파이썬 코드) -> Docker 이미지로 생성하여 저장할 저장소
- esc.tf        : ECS 클러스터와 Fargate Task Definition 등이 구동되는 실행 환경 제공 -> 일회성 (상시 운영x)
- outputs.tf    : 생성 후 각종 정보 출력