# ecs -> cloudwatch -> s3, kinesis,... (외부연결 x)
resource "aws_security_group" "fargate" {
  name = "${var.project_name}-fargate-sg"
  description = "외부 연결 없이 fargate 전용"
  vpc_id = aws_vpc.this.id
  # ingress에 대한 allow(허가) 정의x -> 모두 차단
  tags = {
    Name = "${var.project_name}-fargate-sg"
  }
}

# ECR push, cloudwatch Logs 전송 행위 -> outbound 허용
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_vpc_security_group_egress_rule
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1" # 모든 프로토콜에 대응
}