resource "aws_vpc" "nodevpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "nodevpc"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id     = aws_vpc.nodevpc.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, 1)


}
resource "aws_subnet" "private_1" {
  vpc_id     = aws_vpc.nodevpc.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, 2)


}

resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.nodevpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.nodevpc.id

  route {
    cidr_block = cidrsubnet(var.vpc_cidr, 8, 2)
    gateway_id = aws_nat_gateway.nat1.id
  }
}

resource "aws_route_table_association" "public-rt-a" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_route_table_association" "private-rt-a" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private-rt.id
}



resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.nodevpc.id

}



resource "aws_nat_gateway" "nat1" {
  subnet_id         = aws_subnet.private_1.id
  connectivity_type = "private"
  tags = {
    Name = "gw NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}


resource "aws_security_group" "allow_tls" {
  name        = "allow_to-ecs"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.nodevpc.id

  tags = {
    Name = "allow_to-ecs"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = aws_vpc.nodevpc.cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = aws_vpc.nodevpc.cidr_block
  from_port         = 20
  ip_protocol       = "tcp"
  to_port           = 20
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = aws_vpc.nodevpc.cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}


resource "aws_vpc_security_group_ingress_rule" "allow_port" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 3000
  ip_protocol       = "tcp"
  to_port           = 3000
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


resource "aws_ecs_cluster" "ecs_cluster" {
  name = "fargate-cluster"
}

data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole" # Replace with your role's name
}

resource "aws_ecs_task_definition" "nodetd" {
  family                   = "nodeapp"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  container_definitions = jsonencode([
    {
      name      = "nodetaskdef"
      image     = "211125642672.dkr.ecr.us-east-1.amazonaws.com/mynodeapp:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          cpu           = 512
          memory        = 1024
        }
      ]
    },

  ])



}

resource "aws_ecs_service" "nodeapp" {
  name            = "nodeapp"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.nodetd.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_1.id] # Ensure these are public subnets
    security_groups  = [aws_security_group.allow_tls.id]
    assign_public_ip = true # Assign a public IP
  }
}




