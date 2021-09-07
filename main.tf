
########### network #########
resource "aws_vpc" "my-vpc-mp" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "mini-project-vpc"
  }
}

resource "aws_subnet" "my-public-subnet-mp" {
  vpc_id     = aws_vpc.my-vpc-mp.id
  cidr_block = "10.0.0.0/24"
  tags = {
    Name = "mini-project-public-subnet"
  }
}

resource "aws_subnet" "my-private-subnet-mp" {
  vpc_id     = aws_vpc.my-vpc-mp.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "mini-project-private-subnet"
  }
}

resource "aws_internet_gateway" "my-ig-mp" {
  vpc_id = aws_vpc.my-vpc-mp.id
  tags = {
    Name = "mini-project-ig"
  }
}

resource "aws_route_table" "my-rt-mp" {
  vpc_id = aws_vpc.my-vpc-mp.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-ig-mp.id
  }

  tags = {
    Name = "mini-project-public-rt"
  }
}

resource "aws_route_table" "my-private-rt-mp" {
  vpc_id = aws_vpc.my-vpc-mp.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.my-nat-gw-mp.id
  }

  tags = {
    Name = "mini-project-private-rt"
  }
}

resource "aws_nat_gateway" "my-nat-gw-mp" {
  allocation_id = aws_eip.my-eip-mp.id
  subnet_id     = aws_subnet.my-private-subnet-mp.id
  tags = {
    Name = "mini-project-nat-gw"
  }
}

resource "aws_route_table_association" "rtb-subnet-private-mp" {

    subnet_id = aws_subnet.my-private-subnet-mp.id  

    route_table_id = aws_route_table.my-private-rt-mp.id  

}

resource "aws_route_table_association" "rtb-subnet-public-mp" {

    subnet_id = aws_subnet.my-public-subnet-mp.id  

    route_table_id = aws_route_table.my-rt-mp.id  

}

###### elastic ip  ########

resource "aws_eip" "my-eip-mp" {
  vpc = true
  tags = {
    Name = "mini-project-eip"
  }
}
/*
resource "aws_eip_association" "my-eip" {
  instance_id   = aws_instance.local-ec2-mp.id
  allocation_id = aws_eip.my-eip-mp.id

}
*/

########security group ##########
resource "aws_security_group" "my-sg-mp" {
  name = "remote-ssh"

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
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
######## data ################
data "aws_ami" "amazon_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

######## my key #########

resource "aws_key_pair" "my-key-mp" {
  key_name   = "mini-project-key"
  public_key = file("${path.module}/my_public_key_mp.txt")
}

############### remote ec2 ####################

resource "aws_instance" "remote-ec2-mp" {
  ami                    = data.aws_ami.amazon_ami.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.my-key-mp.id
  vpc_security_group_ids = [aws_security_group.my-sg-mp.id]
  tags = {
    "Name" = element(var.tags, 0)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install -y wget",
      "sudo yum install -y httpd",
      "sudo cd /var/www/html",
      "sudo wget https://devops14-mini-project.s3.amazonaws.com/default/index-default.html",
      "sudo wget https://devops14-mini-project.s3.amazonaws.com/default/mycar.jpeg",
      "sudo mv index-default.html index.html",
      "sudo systemctl enable httpd --now"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("/root/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
}

############### local ec2 #################

resource "aws_instance" "local-ec2-mp" {
  ami           = data.aws_ami.amazon_ami.id
  instance_type = "t2.micro"
  key_name = aws_key_pair.my-key-mp.id
  vpc_security_group_ids = [aws_security_group.my-sg-mp.id]

  provisioner "local-exec" {
      command = "echo ${aws_instance.local-ec2-mp.private_ip} >> public_ips.txt"
    
  }
  tags = {
    "name" = element(var.tags, 0)
  }

}
############### variables #################

variable "tags" {
  type = list(any)
  default = ["local-ec2-mp", "remote-ec2-mp"]
  
}
variable "region" {
  default = "us-east-2"

}

######## time format ###############

locals {
  time = formatdate("DD MM YYYY hh:mm ZZZ", timestamp())

}

output "timestamp" {
  value = local.time

}