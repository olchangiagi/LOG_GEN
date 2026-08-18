# 로그 생성기가 구동되는 컨테이너의 이미지가 저장되는 저장소
# 1. 저장소 생성
resource "aws_ecr_repository" "generator" {
  name = local.repository.name
  #저장소가 삭제될때 -> 남아 있는 이미지가 있다면 -> 삭제 x or 이미지 삭제 + 저장소 삭제 옵션
  force_delete = true

  # 같은 태그로 이미지 갱신 허용
  image_tag_mutability = "MUTABLE"

  # 이미지 푸시시 자동 검사
  image_scanning_configuration {
    scan_on_push = true
  }
}

# 2. 저장소 저장 비용 관리 정책 결정
resource "aws_ecr_lifecycle_policy" "generator" {
  repository = aws_ecr_repository.generator
  policy = jsoncode({
    rules = [
        {
            rulePriority = 1
            description = "keep 20 images"
            selecetion = { 
                tagStatus = "any" # 태그 타입 상관 없음
                countType = "imageCountMoreThan" # 20개 초과시 액션 시작
                countNumber = 20
            }
            # 삭제 행동
            action = {
                type = "expire"
            }
        }
    ]
  })
}
