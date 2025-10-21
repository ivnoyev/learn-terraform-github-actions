provider "aws" { region = "eu-central-1" }

resource "random_pet" "sg" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  owners = ["099720109477"]
}

resource "aws_security_group" "jmeter_sg" {
  name   = "${random_pet.sg.id}-sg"
  vpc_id = data.aws_vpc.default.id

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
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8086
    to_port     = 8086
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

resource "aws_instance" "jmeter_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.jmeter_sg.id]
  key_name               = "jmeter-ssh-key"
  user_data              = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y openjdk-11-jdk wget
    wget https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-5.6.3.tgz
    tar -xzf apache-jmeter-5.6.3.tgz -C /opt
    ln -s /opt/apache-jmeter-5.6.3 /opt/jmeter
    echo "server.rmi.ssl.disable=true" >> /opt/jmeter/bin/jmeter.properties
  EOF
  tags                   = { Name = "JMeter-Master" }
}

resource "aws_instance" "jmeter_slave" {
  count                  = 1
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.jmeter_sg.id]
  key_name               = "jmeter-ssh-key"
  user_data              = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y openjdk-11-jdk wget
    wget https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-5.6.3.tgz
    tar -xzf apache-jmeter-5.6.3.tgz -C /opt
    ln -s /opt/apache-jmeter-5.6.3 /opt/jmeter
    echo "server.rmi.ssl.disable=true" >> /opt/jmeter/bin/jmeter.properties
    /opt/jmeter/bin/jmeter-server &
  EOF
  tags                   = { Name = "JMeter-Slave-${count.index}" }
}

resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.jmeter_sg.id]
  key_name               = "jmeter-key"
  user_data              = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io
    docker run -d -p 8086:8086 --name influxdb influxdb:2.7
    docker exec influxdb influx setup --org jmeter-org --bucket jmeter --username admin --password admin1234 --token my-token --force
    docker run -d -p 3000:3000 --name grafana grafana/grafana
    EOF
  tags                   = { Name = "Monitoring" }
}

output "master_ip" { value = aws_instance.jmeter_master.public_ip }
output "slave_ip" { value = aws_instance.jmeter_slave[0].private_ip }
output "monitoring_ip" { value = aws_instance.monitoring.public_ip }
output "monitoring_private_ip" { value = aws_instance.monitoring.private_ip }