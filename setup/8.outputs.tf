output "airflow_ip_addr" {
    value = "${module.ec2_instance.public_ip}:8080"
}

output "s3_path" {
    value = "s3://${aws_s3_bucket.raw_data_bucket.bucket}"

}

output "RAW_DATA_PATH" {
    value = "s3a://${aws_s3_bucket.raw_data_bucket.bucket}/${aws_s3_object.raw_data.key}"
}

output "aurora_endpoint" {
    value = "${module.aurora.cluster_endpoint}"
}

output "subnet_id" {
    value = "${module.vpc.private_subnets[0]}"
}




