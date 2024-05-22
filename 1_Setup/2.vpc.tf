module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

}

module "security_group_ec2" {
  source = "terraform-aws-modules/security-group/aws"
  name        = "security-group-ec2"
  description = "security-group-ec2"
  vpc_id      = module.vpc.vpc_id

  egress_rules = [ "all-all" ]
  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

module "security_group_msk" {
  source = "terraform-aws-modules/security-group/aws"
  name        = "security-group-msk"
  description = "security-group-msk"
  vpc_id      = module.vpc.vpc_id

  egress_rules = [ "all-all" ]
  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 9092
      to_port     = 9096
      protocol    = "tcp"
      description = "kafka"
      cidr_blocks = "10.0.0.0/16"
    }
  ]
}