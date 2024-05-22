module "msk_kafka_cluster" {
  source = "terraform-aws-modules/msk-kafka-cluster/aws"

  name                   = "my-msk-cluster"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 3
  enhanced_monitoring    = "PER_TOPIC_PER_PARTITION"

  broker_node_client_subnets = [module.vpc.private_subnets[0], module.vpc.private_subnets[1], module.vpc.private_subnets[2]]
  broker_node_storage_info = {
    ebs_storage_info = { volume_size = 100 }
  }
  broker_node_instance_type   = "kafka.m7g.large"
  broker_node_security_groups = [module.security_group_msk.security_group_id]
  
  encryption_in_transit_client_broker = "PLAINTEXT"
  encryption_in_transit_in_cluster    = true

  jmx_exporter_enabled    = true
  node_exporter_enabled   = true
  cloudwatch_logs_enabled = true

  configuration_name        = "msk-configuration"
  configuration_description = "msk configuration"
  configuration_server_properties = {
    "auto.create.topics.enable" = true
    "delete.topic.enable"       = true
    "replica.selector.class" = "org.apache.kafka.common.replica.RackAwareReplicaSelector"
  }
}