provider "aws" { region = "eu-central-1" }

resource "random_pet" "sg" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter { name = "name", values = ["ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"] }
  owners = ["099720109477"]
}

resource "aws_security_group" "jmeter_sg" {
  name = "${random_pet.sg.id}-sg"
  ingress {
    from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"]
  }
  egress { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_instance" "jmeter_master" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  security_groups = [aws_security_group.jmeter_sg.name]
  key_name = "jmeter-key"
  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y openjdk-11-jdk wget
    wget https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-5.6.3.tgz
    tar -xzf apache-jmeter-5.6.3.tgz -C /opt
    ln -s /opt/apache-jmeter-5.6.3 /opt/jmeter
    echo "server.rmi.ssl.disable=true" >> /opt/jmeter/bin/jmeter.properties
  EOF
  tags = { Name = "JMeter-Master" }
}

resource "aws_instance" "jmeter_slave" {
  count = 1
  ami = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  security_groups = [aws_security_group.jmeter_sg.name]
  key_name = "jmeter-key"
  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y openjdk-11-jdk wget
    wget https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-5.6.3.tgz
    tar -xzf apache-jmeter-5.6.3.tgz -C /opt
    ln -s /opt/apache-jmeter-5.6.3 /opt/jmeter
    echo "server.rmi.ssl.disable=true" >> /opt/jmeter/bin/jmeter.properties
    /opt/jmeter/bin/jmeter-server &
  EOF
  tags = { Name = "JMeter-Slave-${count.index}" }
}

resource "aws_instance" "monitoring" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  security_groups = [aws_security_group.jmeter_sg.name]
  key_name = "jmeter-key"
  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y docker.io
    docker run -d -p 8086:8086 influxdb:2.7
    docker run -d -p 3000:3000 grafana/grafana
  EOF
  tags = { Name = "Monitoring" }
}