terraform {
  backend "s3" {
    bucket         = "terraform-state-correction-test"
    key            = "asg-app/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

# Proveedor AWS
provider "aws" {
  region = var.region
}

# 1. Redes (VPC, Subredes, Internet Gateway)
resource "aws_vpc" "app_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "AppVPC"
  }
}

resource "aws_subnet" "public_subnets" {
  count                   = 2 # Crea dos subredes
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true # Para que las instancias tengan IP pública
  tags = {
    Name = "PublicSubnet-${count.index + 1}"
  }
}

data "aws_availability_zones" "available" {} # Obtiene las Zonas de Disponibilidad

resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app_vpc.id
  tags = {
    Name = "AppIGW"
  }
}

resource "aws_route_table" "app_rt" {
  vpc_id = aws_vpc.app_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_igw.id
  }
}

resource "aws_route_table_association" "app_rta" {
  count          = 2
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.app_rt.id
}

# 2. Grupos de Seguridad (SG)
resource "aws_security_group" "lb_sg" {
  vpc_id = aws_vpc.app_vpc.id
  name   = "lb-sg"
  ingress { # Permitir tráfico HTTP desde cualquier lugar (0.0.0.0/0)
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

resource "aws_security_group" "instance_sg" {
  vpc_id = aws_vpc.app_vpc.id
  name   = "instance-sg"
  ingress { # Permitir tráfico HTTP SOLAMENTE desde el Load Balancer (Requisito de Network ASG)
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id] # <- RESTRICCIÓN DE NETWORK
  }
  ingress { # Permitir SSH para depuración (opcional, desde tu IP o 0.0.0.0/0 temporalmente)
    from_port   = 22
    to_port     = 22
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

# 3. Application Load Balancer (ALB)
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [for s in aws_subnet.public_subnets : s.id]
}

resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.app_vpc.id
  health_check {
    path                = "/" # Comprueba la raíz de tu aplicación Flask
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.app_tg.arn
    type             = "forward"
  }
}

# 4. Launch Template (Inyección de Docker)
resource "aws_launch_template" "app_lt" {
  name_prefix   = "app-launch-template"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = "key-ec2" # <-- ¡IMPORTANTE! Reemplaza con el nombre de tu par de claves SSH de AWS.
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Instala Docker (común en Amazon Linux 2)
    sudo dnf update -y
    sudo dnf install docker -y
    sudo service docker start
    sudo usermod -a -G docker ec2-user
    
    # 🚨 PULL y RUN de la imagen de Docker 🚨
    # ¡Reemplaza 'tu-usuario-docker' con tu usuario de Docker Hub o el repositorio que uses!
    # El tag se pasa como variable de Terraform, que se actualizará con GitHub Actions.
    sudo docker pull gabotor0/hello_world_correction:${var.docker_image_tag}
    sudo docker run -d -p 80:80 -e IMAGE_TAG=${var.docker_image_tag} gabotor0/hello_world_correction:${var.docker_image_tag}
  EOF
  )
}

# 5. Auto Scaling Group (ASG)
resource "aws_autoscaling_group" "app_asg" {
  # 🚨 REQUISITO DE NETWORK 🚨: El ASG debe lanzarse en subredes públicas.
  vpc_zone_identifier = [for s in aws_subnet.public_subnets : s.id]

  desired_capacity    = 2
  max_size            = 4
  min_size            = 2
  target_group_arns   = [aws_lb_target_group.app_tg.arn]
  health_check_type   = "ELB"
  force_delete        = true

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest" # Usa la última versión del Launch Template
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  } 
  tag {
    key                 = "Name"
    value               = "AppInstance"
    propagate_at_launch = true
  }
}