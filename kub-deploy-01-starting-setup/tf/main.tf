/*
terraform { 
  cloud { 
    
    organization = "alkatzo-dev" 

    workspaces { 
      name = "dev1" 
    } 
  } 
}
*/

// Create a VPC for the cluster
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  # pin a recent major version; change as needed
  version = "~> 3.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_support   = true
  enable_dns_hostnames = true
}

// EKS cluster using the community module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.34"

  subnet_ids = module.vpc.private_subnets
  vpc_id  = module.vpc.vpc_id

  enable_irsa = true

  eks_managed_node_groups = {
    workers = {
      name            = "workers"
      use_name_prefix = false
      desired_size = var.node_group_desired_size
      max_size     = var.node_group_max_size
      min_size     = var.node_group_min_size

      instance_types = [var.node_group_instance_type]

      # Place nodes in public subnets and enable public IPs
      subnet_ids = module.vpc.public_subnets
      
      # Enable public IP assignment via launch template
      network_interfaces = [{
        associate_public_ip_address = true
        delete_on_termination       = true
      }]

      # attach key pair if provided
      key_name = var.key_name != "" ? var.key_name : (var.create_ssh_key ? aws_key_pair.worker[0].key_name : null)
    }
  }
}
