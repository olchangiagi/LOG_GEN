locals {
    # 자동으로 계산하여 AZ 영역 결정 -> a, b 선택될 것.
    availabilty_zone = slice(
        data.aws_availability_zones.availablty.names,
        0, # 시작 인덱스
        length(var.public_subnet_cidrs) # 끝 인덱스 -> 2
    )

    # 기타 이름 설정
    cluster_name = "${var.project_name}-cluster"
    task_family = "${var.project_name}-task"
    repository = "${var.project_name}-repository"
    log_group_name = "/ecs/${var.project_name}"
}

