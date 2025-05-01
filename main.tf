terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "MainVPC"
  }
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "SubnetA"
  }
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "SubnetB"
  }
}

resource "aws_security_group" "example_sg" {
  name        = "example_sg"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Allow RDS access if needed (minimal setup, adjust as needed)
resource "aws_security_group" "allow_rds" {
  name        = "allow_rds"
  description = "Allow access to RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ⚠️ For testing only — lock this down in prod!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "MainIGW"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRoute"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_instance" "example" {
  count                  = 2
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  key_name               = "terraform" # Replace with your key
  #subnet_id              = aws_subnet.subnet_a.id
  subnet_id              = element([aws_subnet.subnet_a.id, aws_subnet.subnet_b.id], count.index)
  vpc_security_group_ids = [aws_security_group.example_sg.id]

  tags = {
    Name = "WebServer-${count.index}"
  }
}

resource "aws_ebs_volume" "example" {
  count             = 2  # same as the number of instances
  #availability_zone = "us-east-1a"
  availability_zone = aws_instance.example[count.index].availability_zone
  size              = 8
  type              = "gp2"

  tags = {
    #Name = "MyEBSVolume"
    Name = "MyEBSVolume-${count.index}"
  }
}

resource "aws_volume_attachment" "example" {
  count       = 2  # attach one volume per instance, or reduce to 1 if only one volume
  device_name = "/dev/sdh"
  #volume_id   = aws_ebs_volume.example.id
  volume_id   = aws_ebs_volume.example[count.index].id
  instance_id = aws_instance.example[count.index].id
}

resource "aws_db_subnet_group" "example" {
  name       = "example-subnet-group"
  subnet_ids = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]

  tags = {
    Name = "Example DB subnet group"
  }
}

resource "aws_db_instance" "example" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0.36"
  instance_class         = "db.t3.micro"
  username               = "admin"
  password               = "yourpassword"
  skip_final_snapshot    = true
  publicly_accessible    = true
  db_subnet_group_name   = aws_db_subnet_group.example.name
  vpc_security_group_ids = [aws_security_group.allow_rds.id]

  tags = {
    Name = "MyDBInstance"
  }
}

resource "aws_s3_bucket" "example" {
  bucket        = "my-example-bucket-unique-20250430"
  force_destroy = true

  tags = {
    Name = "My Example Bucket"
  }
}

resource "aws_cloudwatch_log_group" "example" {
  name = "/aws/terraform-example"
}

resource "aws_lb_target_group" "example" {
  name     = "web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

resource "aws_lb_target_group_attachment" "example" {
  count            = 2
  target_group_arn = aws_lb_target_group.example.arn
  target_id        = aws_instance.example[count.index].id
  port             = 80
}

resource "aws_lb" "example" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.example_sg.id]
  subnets            = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]

  tags = {
    Name = "WebALB"
  }
}

resource "aws_lb_listener" "example" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }
}

