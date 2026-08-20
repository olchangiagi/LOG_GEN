# Fargate는 ECR TASK(로그 생성)를 생성하여 CloudWatch에 저장
# ECR에 등록된 이미지(PUSH 작업 진행), CloudWatch에 저장(로그 전송) -> 2개 권한 필요
# 1. ECR TASK policy 조회(어떤 것이 가능-> xx.amazon.com )
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
# 2. 해당 Role 정의(생성)
resource "aws_iam_role" "ecs_execution" {
  name               = "${var.project_name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

# 3. Role, 정책 연결 마무리, 실제 실행시 필요한 권한 부여!!
resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  # aws 관리형 정책을 사전에 AmazonECSTaskExecuytuinRolePolicy 구성(이 정책에 1번 라인에 기술한 내용 반영)
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# [브론즈 추가]
# aws_iam_policy_document -> aws_iam_role -> aws_iam_rile_policy_attachment(필요시 추가)
# firehose에서 iam Role을 사용하도록 신뢰 정책 조회
data "aws_iam_policy_document" "firehose_assume"{
    statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "firehose_execution" {
  # role의 이름 (고유, )
  name               = "${var.project_name}-firehose-role"
  # role에 적용되는 정책 -> 어떤 권한을 가지는가?
  assume_role_policy = data.aws_iam_policy_document.firehose_assume.json
}

# firehose가 입력으로 kinesis에서 읽어오고, 출력으로 s3에 저장 -> 권한 구성
data "aws_iam_policy_document" "firehose_s3" {
  # kinesis 읽기 권한 관련 
  

  # s3 저장 권한 관련

}

# firehose_s3를 통해서 조회한 권한을 aws_iam_rile.firehose에 부여
resource "aws_iam_role_policy" "firehose" {
  name = "${var.project_name}-firehose-s3-policy"
  role = aws_iam_role.firehose.id
  policy = data.aws_iam_policy_document.firehose_s3.json
}