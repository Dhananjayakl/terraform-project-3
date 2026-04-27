output "vpc_id" {
  value = aws_vpc.main.id
}

output "instance_id" {
  value = aws_instance.main.id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.tf_state.bucket
}

output "security_group_id" {
  value = aws_security_group.main.id
}