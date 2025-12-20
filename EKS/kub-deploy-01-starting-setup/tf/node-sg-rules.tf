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
