module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name                   = "airflow_ec2"
  ami                    = "ami-080e1f13689e07408"
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  instance_type          = "m5.large"
  monitoring             = true
  associate_public_ip_address = true
  root_block_device = [{
    volume_type = "gp3"
    volume_size = 100
  }]
  depends_on = [ module.vpc, module.security_group_ec2, aws_iam_role.airflow-ec2-role, aws_iam_instance_profile.ec2_profile ]
  vpc_security_group_ids = split(" ", module.security_group_ec2.security_group_id)
  subnet_id              = module.vpc.public_subnets[0]
  user_data = <<EOF
#!/bin/bash 

sudo apt-get update
sudo sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
sudo apt-get install python3-pip -y
sudo apt-get install mysql-client-core-8.0 -y
sudo apt-get  install awscli -y
mkdir ~/airflow
mkdir ~/airflow/dags
export AIRFLOW_HOME=~/airflow
sudo pip3 install apache-airflow
sudo pip3 install apache-airflow-providers-amazon
airflow db init
airflow users create \
    --username admin \
    --password admin \
    --firstname aws \
    --lastname admin \
    --role Admin \
    --email admin@test.com

nohup airflow webserver --port 8080 &
nohup airflow scheduler &

EOF
}