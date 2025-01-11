output "aws_vpc_name" {
  value = aws_vpc.nodevpc.tags["Name"]

}

output "aws_vpc_id" {
  value = aws_vpc.nodevpc.id
}

output "security_group_id" {
  value = aws_security_group.allow_tls.id
}
