data "aws_iam_policy_document" "assume_role_ec2" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "assume_role_emr" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["elasticmapreduce.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "airflow-ec2-role" {
  name               = "airflow-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ec2.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEMRFullAccessPolicy_v2", "arn:aws:iam::aws:policy/AmazonS3FullAccess"]
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "airflow_ec2_profile"
  role = aws_iam_role.airflow-ec2-role.name
}

resource "aws_iam_role" "emr-service-role" {
  name               = "emr-service-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_emr.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"]
}

resource "aws_iam_role" "emr-ec2-role" {
  name               = "emr-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ec2.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"]
}

resource "aws_iam_instance_profile" "emr_ec2_profile" {
  name = "emr-ec2-role"
  role = aws_iam_role.emr-ec2-role.name
}