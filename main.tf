resource "awscc_ec2_ipam" "main" {
  operating_regions = [
    {
      region_name = "us-east-1"
    },
    {
      region_name = "us-east-2"
    }
  ]
  tags = [{
    key   = "Name"
    value = "global-ipam"
  }]
}

resource "awscc_ec2_ipam_pool" "root" {
  address_family = "ipv4"
  // allocation_resource_tags = [] // Can be used to enforce tagging of resources in the VPC?
  auto_import = false
  //aws_service              = ""
  description   = "Parent IP Pool for VPCs"
  ipam_scope_id = awscc_ec2_ipam.main.private_default_scope_id
  provisioned_cidrs = [{
    cidr = "10.0.0.0/16"
  }]
  tags = [{
    key   = "Name"
    value = "top-level-pool"
  }]
}

resource "awscc_ec2_ipam_pool" "useast1" {
  address_family = "ipv4"
  //allocation_resource_tags = []
  auto_import = false
  //aws_service              = ""
  description   = "Regional pool to provision IP addresses from in us-east-1"
  ipam_scope_id = awscc_ec2_ipam.main.private_default_scope_id
  locale        = "us-east-1"
  provisioned_cidrs = [{
    cidr = "10.0.0.0/17"
  }]
  source_ipam_pool_id = awscc_ec2_ipam_pool.root.ipam_pool_id
  tags = [
    {
      key   = "Name"
      value = "regional-pool-us-east-1"
    }
  ]
}

resource "awscc_ec2_ipam_pool" "useast2" {
  address_family = "ipv4"
  //allocation_resource_tags = []
  auto_import = false
  //aws_service              = ""
  description   = "Regional pool to provision IP addresses from in us-east-2"
  ipam_scope_id = awscc_ec2_ipam.main.private_default_scope_id
  locale        = "us-east-2"
  provisioned_cidrs = [
    {
      cidr = "10.0.128.0/17"
    }
  ]
  source_ipam_pool_id = awscc_ec2_ipam_pool.root.ipam_pool_id
  tags = concat([
    {
      key   = "Name"
      value = "regional-pool-us-east-2"
    }
    ],
  module.tags_shared.tags)
}

resource "aws_vpc" "useast2" {
  enable_dns_hostnames = true
  enable_dns_support   = true

  ipv4_ipam_pool_id   = awscc_ec2_ipam_pool.useast2.id
  ipv4_netmask_length = 24

  depends_on = [awscc_ec2_ipam_pool.useast2]
  tags = merge({
    Name = "us-east-2-private"
    },
    module.tags_shared.tags_aws
  )
}

resource "aws_vpc" "useast1" {
  provider = aws.useast1

  enable_dns_hostnames = true
  enable_dns_support   = true

  ipv4_ipam_pool_id   = awscc_ec2_ipam_pool.useast1.id
  ipv4_netmask_length = 24

  depends_on = [awscc_ec2_ipam_pool.useast1]
  tags = merge({
    Name = "us-east-1-private"
    },
    module.tags_shared.tags_aws
  )
}

# reconcile tag API differences between providers: .tags_aws = aws provider format ; .tags = awscc provider format
module "tags_shared" {
  source = "aws-ia/label/aws"
  tags = {
    terraform  = true
    CostCenter = "enterprise-architecture"
  }
}