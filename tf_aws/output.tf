output "instance_public_ip" {
  value = aws_spot_instance_request.clickhouse.*.public_ip
}

output "instance_private_ip" {
  value = aws_spot_instance_request.clickhouse.*.private_ip
}