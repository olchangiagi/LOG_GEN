# Fargate는 ECR task(로그 생성)를 생성하여 cloudwatch에 저장
# ECR에 등록된 이미지(PUSH 작업 진행), cloudwatch에 저장(로그 전송) -> 2개 권한 필요

# 1. ECR Task policy (어떤 것이 가능 -> xx.amazon.com)
data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["ecs-task.amazonaws.com"]
    }
  }
}

# 2. 해당 Role 정의(설정)
resource "aws_iam_role" "ecs_execution" {
  name               = "$(var.project_name}-ecs-excution"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json
}

# 3. Role, 정책 연결 마무리
resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/Amazone-role/AmazonECSTaskExecutionLolrolepoilicy"
}