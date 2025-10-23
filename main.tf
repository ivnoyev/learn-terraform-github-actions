provider "aws" {
  region = "eu-central-1"
}

resource "random_pet" "sg" {}

resource "aws_security_group" "jmeter_sg" {
  name = "${random_pet.sg.id}-sg"

  ingress {
    from_port   = 1099
    to_port     = 1099
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
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

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  owners = ["099720109477"]
}

resource "aws_instance" "jmeter_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.jmeter_sg.id]
  key_name               = "jmeter-ssh-key"
  user_data              = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y openjdk-11-jdk wget openssh-server
    systemctl enable ssh
    systemctl start ssh
    wget -q https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-5.6.3.tgz
    tar -xzf apache-jmeter-5.6.3.tgz -C /opt
    ln -s /opt/apache-jmeter-5.6.3 /opt/jmeter
    echo "server.rmi.ssl.disable=true" >> /opt/jmeter/bin/jmeter.properties
  EOF
  tags                   = { Name = "JMeter-Master" }
}

resource "aws_instance" "jmeter_slave" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.jmeter_sg.id]
  key_name               = "jmeter-ssh-key"
  user_data              = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y openjdk-11-jdk wget openssh-server
    wget -q https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-5.6.3.tgz
    tar -xzf apache-jmeter-5.6.3.tgz -C /opt
    ln -s /opt/apache-jmeter-5.6.3 /opt/jmeter
    echo "server.rmi.ssl.disable=true" >> /opt/jmeter/bin/jmeter.properties
    /opt/jmeter/bin/jmeter-server &
  EOF
  tags                   = { Name = "JMeter-Slave" }
}

output "master_ip" { value = aws_instance.jmeter_master.public_ip }
output "slave_ip" { value = aws_instance.jmeter_slave.private_ip }