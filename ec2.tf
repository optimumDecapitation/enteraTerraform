variable "access_key_aws" {
  default = "ENTER YOUR AWS PROVIDER ID HERE"
}
variable "secret_key_aws" {
  default = "ENTER YOUR AWS SECRET HERE"
}
variable "vpc_id" {
  default = "ENTER THE TARGET VPC HERE" #THIS FILE IS SPECIFICALLY FOR THE EU-WEST-1B REGION/AVAILABILITY-ZONE
}
variable "ssh_key" {
  default  = "ENTER YOUR DESIRED SSH PUBLIC KEY HERE" # ADD THE PRIVATE TO YOUR LOCAL SSH CONFIGURATION
}
variable "ssh_ip" {
  default  = "ENTER YOUR IP FOR SSH HERE" #SHOULD BE IN CIDR NOTATION
}



provider "aws" {
  access_key = "${var.access_key_aws}"
  secret_key = "${var.secret_key_aws}"
  region     = "eu-west-1"
  
}
data "aws_vpc" "selected" {
  id = "${var.vpc_id}"
}

resource "aws_security_group" "ssh_provision" {
  name        = "ssh_provision"
  description = "Allow ssh traffic for repo-less docker build"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.ssh_ip}"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "open_web" {
  name        = "open_web"
  description = "Allow web ingress and all egress through the ELB"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ruby" {
  name        = "ruby"
  description = "Allow ingress to ruby app port"

  ingress {
    from_port   = 2345
    to_port     = 2345
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "cadvisor" {
  name        = "cadvisor"
  description = "Allow ingress to cadvisor port"

  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "grafana" {
  name        = "grafana"
  description = "Allow ingress to grafana port"

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "prometheus" {
  name        = "prometheus"
  description = "Allow ingress to prometheus port"

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "internal" {
  name        = "internal"
  description = "Allow web ingress and all egress through the ELB"

  ingress {
     from_port       = 80
     to_port         = 80
     protocol        = "tcp"
     cidr_blocks     = ["${data.aws_vpc.selected.cidr_block}"]
  }

  egress {
     from_port       = 80
     to_port         = 80
     protocol        = "tcp"
     cidr_blocks     = ["${data.aws_vpc.selected.cidr_block}"]
  }
}

resource "aws_key_pair" "deploySite_key" {
  key_name   = "deploySite_key"
  public_key = "${var.ssh_key}"
  }


resource "aws_instance" "dockerHost" {
  ami           = "ami-0d7e8a38d69832b2e"
  instance_type = "t2.micro"
  key_name = "deploySite_key"
  availability_zone = "eu-west-1b"
  security_groups = ["${aws_security_group.ssh_provision.name}","${aws_security_group.internal.name}","${aws_security_group.cadvisor.name}","${aws_security_group.grafana.name}","${aws_security_group.ruby.name}","${aws_security_group.prometheus.name}"]
  connection {
      type = "ssh"
      user = "admin"
      agent = true
  }
    provisioner "remote-exec" {
      inline = [
        "sudo apt-get update",
        "sudo apt-get install -y docker",
        "sudo apt-get install -y git",
        "git clone https://github.com/optimumDecapitation/dockerNginxSite.git",
        "git clone https://github.com/optimumDecapitation/enteraDocker.git",
        "sudo bash enteraDocker/buildAndLaunchStack.sh",
        "sudo bash dockerNginxSite/provisionDeploy.sh"
      ]
    }
}

resource "aws_elb" "dock" {
  name               = "nginx-terraform-elb"
  availability_zones = ["eu-west-1b"]
  security_groups = ["${aws_security_group.open_web.id}","${aws_security_group.internal.id}","${aws_security_group.cadvisor.name}","${aws_security_group.grafana.name}","${aws_security_group.ruby.name}","${aws_security_group.prometheus.name}"]
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  listener {
    instance_port     = 2345
    instance_protocol = "http"
    lb_port           = 2345
    lb_protocol       = "http"
  }

  listener {
    instance_port     = 3000
    instance_protocol = "http"
    lb_port           = 3000
    lb_protocol       = "http"
  }

  listener {
    instance_port     = 8081
    instance_protocol = "http"
    lb_port           = 8081
    lb_protocol       = "http"
  }

  listener {
    instance_port     = 9090
    instance_protocol = "http"
    lb_port           = 9090
    lb_protocol       = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  instances                   = ["${aws_instance.dockerHost.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "nginx-terraform-elb"
  }
}