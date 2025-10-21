output "master_ip" { value = aws_instance.jmeter_master.public_ip }
output "slave_ip" { value = aws_instance.jmeter_slave[0].private_ip }
output "monitoring_ip" { value = aws_instance.monitoring.public_ip }
output "monitoring_private_ip" { value = aws_instance.monitoring.private_ip }