module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name                   = "msk-pub/sub"
  ami                    = "ami-0a699202e5027c10d"
  instance_type          = "m5.large"
  monitoring             = true
  associate_public_ip_address = true
  root_block_device = [{
    volume_type = "gp3"
    volume_size = 100
  }]
  depends_on = [ module.vpc, module.security_group_ec2]
  vpc_security_group_ids = split(" ", module.security_group_ec2.security_group_id)
  subnet_id              = module.vpc.public_subnets[0]
  user_data = <<EOF
#!/bin/bash 

sudo yum install java-1.8.0-openjdk -y
cd /home/ec2-user
wget https://dlcdn.apache.org/kafka/3.7.0/kafka_2.13-3.7.0.tgz
tar -xzf kafka_2.13-3.7.0.tgz
echo "log4j.logger.org.apache.kafka.clients.consumer.internals.Fetcher=DEBUG" >> /home/ec2-user/kafka_2.13-3.7.0/config/tools-log4j.properties

EOF
}

