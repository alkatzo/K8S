# EKS cluster (Sydney) Terraform

This folder contains a minimal Terraform configuration to create an EKS cluster in the Sydney region (ap-southeast-2). It creates a VPC and an EKS cluster with a single managed node group. Adjust variables before applying.

Quick steps:

1. Install Terraform 1.2+.
2. Configure AWS credentials in your environment (e.g., `AWS_PROFILE` or `AWS_ACCESS_KEY_ID` & `AWS_SECRET_ACCESS_KEY`).
3. Initialize Terraform:

```powershell
cd tf
terraform init
```

4. Plan and apply:

```powershell
terraform plan -out plan.tfplan
terraform apply plan.tfplan
```

Notes:
- The module versions used here are reasonably recent; pin or update module versions as needed.
- Costs: this will create EC2 instances, NAT gateway and other billable resources in your AWS account.
- If you want public worker nodes or different subnet configuration, update `variables.tf`.

## Query resources by tag (AWS CLI)

After you apply the Terraform configuration you may want to find all AWS resources created for this project. We add a `Project` tag (provider default-tags) so you can search by that tag.

Replace `users-eks-cluster` with the `Project` tag value you used (default is the `cluster_name` variable).

List resources with the `Project` tag (single region):

```bash
REGION="ap-southeast-2"
PROJECT_VALUE="users-eks-cluster"

aws resourcegroupstaggingapi get-resources \
	--region "$REGION" \
	--tag-filters Key=Project,Values="$PROJECT_VALUE" \
	--output json > resources-with-project.json

# show ARNs
jq -r '.ResourceTagMappingList[].ResourceARN' resources-with-project.json
```

Iterate across all regions:

```bash
PROJECT_VALUE="users-eks-cluster"
for region in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); do
	echo "=== $region ==="
	aws resourcegroupstaggingapi get-resources \
		--region "$region" \
		--tag-filters Key=Project,Values="$PROJECT_VALUE" \
		--output json \
		| jq -r '.ResourceTagMappingList[].ResourceARN' || true
done
```

EC2 instances with the tag (fast):

```bash
aws ec2 describe-instances \
	--region ap-southeast-2 \
	--filters "Name=tag:Project,Values=users-eks-cluster" \
	--query 'Reservations[].Instances[].{ID:InstanceId,IP:PrivateIpAddress,State:State.Name}' \
	--output table
```

S3 buckets (check tags per-bucket):

```bash
for b in $(aws s3api list-buckets --query 'Buckets[].Name' --output text); do
	if aws s3api get-bucket-tagging --bucket "$b" 2>/dev/null \
			| jq -e '.TagSet[] | select(.Key=="Project" and .Value=="users-eks-cluster")' >/dev/null; then
		echo "Bucket: $b"
	fi
done
```

Notes:
- The Resource Groups Tagging API (`resourcegroupstaggingapi:GetResources`) is the easiest way to find most tagged resources, but not all resource types are supported. Use resource-specific describe commands if something is missing from results.
- Iterate regions to be thorough; some resources are regional or global (IAM).
 - Iterate regions to be thorough; some resources are regional or global (IAM).

Quick one-liner (all regions)
:
If you just want a compact one-liner that prints ARNs for every resource tagged with Project across all regions, run:

```bash
PROJECT=users-eks-cluster; for r in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); do aws resourcegroupstaggingapi get-resources --region $r --tag-filters Key=Project,Values=$PROJECT --query 'ResourceTagMappingList[].ResourceARN' --output text; done
```

IAM and a few global resources are not returned by the regional tagging API; for those check IAM directly (roles, instance profiles) with `aws iam list-roles` and filter by tag when available.

## SSH access to worker nodes

This repository offers optional, controlled SSH access to worker nodes. The Terraform variables that control this behavior are defined in `variables.tf`:

- `key_name` — an existing EC2 key pair name to attach to worker nodes (default: empty).
- `create_ssh_key` — when `true`, Terraform will import the `ssh_public_key` as an `aws_key_pair` and use it for the worker nodes.
- `ssh_public_key` — the public key material (e.g. the contents of `~/.ssh/id_rsa.pub`) used when `create_ssh_key=true`.
- `ssh_allowed_cidr` — the CIDR range that is allowed to SSH to worker nodes (e.g. `203.0.113.5/32`). Leave empty to avoid creating an SSH SG rule.

Usage examples:

1) Use an existing AWS key pair and allow SSH from your IP:

```bash
cd tf
terraform apply \
	-var 'key_name=existing-aws-key' \
	-var "ssh_allowed_cidr=$(curl -s https://checkip.amazonaws.com)/32" \
	-auto-approve
```

2) Import your public key and allow SSH from your IP (Terraform imports the public key only):

```bash
cd tf
terraform apply \
	-var 'create_ssh_key=true' \
	-var "ssh_public_key=$(cat ~/.ssh/id_rsa.pub)" \
	-var "ssh_allowed_cidr=$(curl -s https://checkip.amazonaws.com)/32" \
	-auto-approve
```

After apply, worker instances will either use the existing key named in `key_name` or the imported key named `<cluster_name>-worker-key`.

To SSH into a worker node:

1. Get node IPs:

```bash
kubectl get nodes -o wide
```

2. From a machine that can reach the node private IPs (a bastion host in the VPC or a machine with VPN access), SSH using your private key:

```bash
# user depends on AMI: commonly ec2-user, ubuntu, or admin
ssh -i ~/.ssh/id_rsa ec2-user@<node-private-ip>
```

Security notes:

- Only open SSH from a restricted CIDR (your IP/32) and avoid `0.0.0.0/0`.
- Terraform imports only public key material; never put private keys into Terraform variables or source control.
- Depending on the node AMI, the login username may vary (check the EKS module AMI or node group configuration).
