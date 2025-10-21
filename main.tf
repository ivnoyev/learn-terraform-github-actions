provider "aws" {
  region = "eu-central-1"
}

resource "random_pet" "sg" {}

# VPC and Subnet
resource "aws_vpc" "jmeter_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "jmeter-vpc" }
}

resource "aws_subnet" "jmeter_subnet" {
  vpc_id     = aws_vpc.jmeter_vpc.id
  cidr_block = "10.0.1.0/24"
  tags       = { Name = "jmeter-subnet" }
}

# JMeter Security Group (RMI: 1099, 50000; SSH: 22)
resource "aws_security_group" "jmeter_sg" {
  name   = "${random_pet.sg.id}-sg"
  vpc_id = aws_vpc.jmeter_vpc.id

  ingress {
    from_port   = 1099
    to_port     = 1099
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  ingress {
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
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
    cidr_blocks = ["0.0.0.0/0"] # For Grafana
  }
  ingress {
    from_port   = 8086
    to_port     = 8086
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # InfluxDB from JMeter
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  owners = ["099720109477"] # Canonical
}

# JMeter Master
resource "aws_instance" "jmeter_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.jmeter_subnet.id
  vpc_security_group_ids = [aws_security_group.jmeter_sg.id]
  key_name               = "jmeter-key"

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y openjdk-11-jdk
    wget https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-5.6.3.tgz
    tar -xzf apache-jmeter-5.6.3.tgz -C /opt
    ln -s /opt/apache-jmeter-5.6.3 /opt/jmeter
    echo "server.rmi.ssl.disable=true" >> /opt/jmeter/bin/jmeter.properties
    echo "mode=Standard" >> /opt/jmeter/bin/jmeter.properties
    EOF

  tags = { Name = "JMeter-Master" }
}

# JMeter Slaves
variable "slave_count" { default = 2 }

resource "aws_instance" "jmeter_slave" {
  count                  = var.slave_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.jmeter_subnet.id
  vpc_security_group_ids = [aws_security_group.jmeter_sg.id]
  key_name               = "jmeter-key"

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y openjdk-11-jdk
    wget https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-5.6.3.tgz
    tar -xzf apache-jmeter-5.6.3.tgz -C /opt
    ln -s /opt/apache-jmeter-5.6.3 /opt/jmeter
    echo "server.rmi.ssl.disable=true" >> /opt/jmeter/bin/jmeter.properties
    echo "mode=Standard" >> /opt/jmeter/bin/jmeter.properties
    /opt/jmeter/bin/jmeter-server &
    EOF

  tags = { Name = "JMeter-Slave-${count.index}" }
}

# Monitoring
resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.jmeter_subnet.id
  vpc_security_group_ids = [aws_security_group.jmeter_sg.id]
  key_name               = "jmeter-key"

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io
    docker run -d -p 8086:8086 influxdb:2.7
    docker run -d -p 3000:3000 grafana/grafana
    EOF

  tags = { Name = "Monitoring" }
}

# Outputs
output "master_ip" { value = aws_instance.jmeter_master.public_ip }
output "slave_ips" { value = join(",", aws_instance.jmeter_slave[*].private_ip) }
output "grafana_url" { value = "http://${aws_instance.monitoring.public_ip}:3000" }