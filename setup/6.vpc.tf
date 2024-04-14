module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true

}

module "security_group_ec2" {
  source = "terraform-aws-modules/security-group/aws"
  name        = "security-group-airflow"
  description = "security-group-airflow"
  vpc_id      = module.vpc.vpc_id

  egress_rules = [ "all-all" ]
  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "Airflow UI Port"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}

module "security_group_aurora" {
  source = "terraform-aws-modules/security-group/aws"
  name        = "security-group-aurora"
  description = "security-group-aurora"
  vpc_id      = module.vpc.vpc_id

  egress_rules = [ "all-all" ]
  ingress_with_cidr_blocks = [
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      description = "Aurora Mysql Security Group"
      cidr_blocks = "10.0.0.0/16"
    },
  ]
}