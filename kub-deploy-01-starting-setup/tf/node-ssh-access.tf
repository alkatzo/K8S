// Optional: import a public SSH key as an aws_key_pair and open SSH from a CIDR to the node SG

resource "aws_key_pair" "worker" {
  count      = var.create_ssh_key ? 1 : 0
  key_name   = "${var.cluster_name}-worker-key"
  public_key = var.ssh_public_key
}

resource "aws_security_group_rule" "allow_ssh_to_nodes" {
  count                     = var.ssh_allowed_cidr != "" ? 1 : 0
  type                      = "ingress"
  from_port                 = 22
  to_port                   = 22
  protocol                  = "tcp"
  security_group_id         = module.eks.node_security_group_id
  cidr_blocks               = [var.ssh_allowed_cidr]
  description               = "Allow SSH from allowed CIDR to worker nodes"
}
