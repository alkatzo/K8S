variable "aws_region" {
  description = "AWS region to create resources in"
  type        = string
  default     = "ap-southeast-2" # Sydney
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "users-eks-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "List of public subnet CIDRs (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  validation {
    condition     = length(var.public_subnets) == length(var.azs)
    error_message = "public_subnets must have the same number of entries as azs"
  }
}

variable "private_subnets" {
  description = "List of private subnet CIDRs (one per AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
  validation {
    condition     = length(var.private_subnets) == length(var.azs)
    error_message = "private_subnets must have the same number of entries as azs"
  }
}

variable "azs" {
  description = "List of AZs to create subnets in (one per subnet CIDR)"
  type        = list(string)
  default     = ["ap-southeast-2a", "ap-southeast-2b"]
}

variable "node_group_instance_type" {
  description = "Instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_group_min_size" {
  type    = number
  default = 1
}

variable "node_group_desired_size" {
  type    = number
  default = 2
}

variable "node_group_max_size" {
  type    = number
  default = 3
}

variable "key_name" {
  description = "Optional EC2 key pair name to attach to worker nodes (empty = none)"
  type        = string
  default     = ""
}

variable "create_ssh_key" {
  description = "If true, Terraform will create an aws_key_pair from the provided public key material. If false, provide an existing key name via `key_name`."
  type        = bool
  default     = false
}

variable "ssh_public_key" {
  description = "Public key material to import as an aws_key_pair when create_ssh_key is true. Use the full public key string (ssh-rsa AAAA...)."
  type        = string
  default     = ""
}

variable "ssh_allowed_cidr" {
  description = "CIDR range allowed to SSH to worker nodes (e.g. your IP/32). Empty = do not create SSH SG rule."
  type        = string
  default     = ""
}
