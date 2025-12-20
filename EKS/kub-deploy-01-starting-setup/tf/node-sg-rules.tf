// Additive security group rule to allow all traffic between worker nodes.
// This references the node security group created by the EKS module and
// only opens traffic between members of that security group (safe scope).

resource "aws_security_group_rule" "allow_intra_nodes_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = module.eks.node_security_group_id
  description              = "Allow all traffic between worker nodes (node SG to node SG)"
}

// Add egress rule to allow all outbound traffic from nodes
resource "aws_security_group_rule" "allow_all_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.eks.node_security_group_id
  description       = "Allow all outbound traffic from worker nodes"
}

// Add rules to the node group-specific security group
resource "aws_security_group_rule" "node_group_ingress_self" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = module.eks.eks_managed_node_groups["workers"].security_group_id
  source_security_group_id = module.eks.eks_managed_node_groups["workers"].security_group_id
  description              = "Allow all traffic within workers node group"
}

resource "aws_security_group_rule" "node_group_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.eks.eks_managed_node_groups["workers"].security_group_id
  description       = "Allow all outbound traffic from workers node group"
}
