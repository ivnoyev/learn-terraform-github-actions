provider "aws" {
  region = "eu-central-1"
}

resource "random_pet" "sg" {}

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

output "master_ip" { value = aws_instance.jmeter_master.public_ip }
output "slave_ip" { value = aws_instance.jmeter_slave[0].private_ip }