
#!/usr/bin/env bash
set -euo pipefail

# Usage: ./tf/cleanup-vpce-by-project.sh [PROJECT]
# Example: ./tf/cleanup-vpce-by-project.sh users-eks-cluster

PROJECT="${1:-users-eks-cluster}"
TMPFILE="$(mktemp)"
declare -a SG_TO_CLEAN=()

echo "Running cleanup for Project=$PROJECT"
echo

# Confirm caller identity
echo "AWS caller identity:"
aws sts get-caller-identity --output json
echo

# Loop regions, find vpce ARNs, describe and optionally delete
for region in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); do
  echo "==== region: $region ===="
  # Get ARNs (may be empty)
  ARNS=$(aws resourcegroupstaggingapi get-resources \
    --region "$region" \
    --tag-filters Key=Project,Values="$PROJECT" \
    --query 'ResourceTagMappingList[].ResourceARN' --output text || true)

  if [ -z "$ARNS" ]; then
    echo "No resources found in $region for Project=$PROJECT"
    continue
  fi

  # iterate through ARNs
  for arn in $ARNS; do
    if [[ "$arn" != *":vpc-endpoint/"* ]]; then
      continue
    fi

    vpce="${arn##*/}"
    echo
    echo "Found VPCE ARN: $arn  (vpce id = $vpce)"
    # Describe (if exists)
    if ! aws ec2 describe-vpc-endpoints --region "$region" --vpc-endpoint-ids "$vpce" >/dev/null 2>&1; then
      echo "  -> Not found in $region (skipping)"
      continue
    fi

    # Print useful details
    aws ec2 describe-vpc-endpoints --region "$region" --vpc-endpoint-ids "$vpce" \
      --query 'VpcEndpoints[0].{Id:VpcEndpointId,Service:ServiceName,State:State,VpcId:VpcId,SubnetIds:SubnetIds,NetworkInterfaceIds:NetworkInterfaceIds,SecurityGroups:Groups[*].GroupId}' \
      --output json | jq || true

    # collect endpoint SG ids (if any) for later cleanup
    mapfile -t found_sgs < <(aws ec2 describe-vpc-endpoints --region "$region" --vpc-endpoint-ids "$vpce" --query 'VpcEndpoints[0].Groups[*].GroupId' --output text || true)
    for sg in "${found_sgs[@]}"; do
      if [ -n "$sg" ] && [[ "$sg" != "None" ]]; then
        SG_TO_CLEAN+=("$sg")
      fi
    done

    # Ask user whether to delete this endpoint
    read -r -p "Delete vpce '$vpce' in region '$region'? [y/N] " ans
    case "$ans" in
      [Yy]* )
        echo "Deleting $vpce in $region..."
        aws ec2 delete-vpc-endpoints --region "$region" --vpc-endpoint-ids "$vpce" \
          && echo "Deleted $vpce" || echo "Failed to delete $vpce"
        ;;
      * )
        echo "Skipping $vpce"
        ;;
    esac
  done
done

# Deduplicate SG list
if [ "${#SG_TO_CLEAN[@]}" -gt 0 ]; then
  echo
  echo "Security groups referenced by described endpoints (candidates for deletion):"
  printf "%s\n" "${SG_TO_CLEAN[@]}" | sort -u
  echo

  # Prompt to attempt deletion of each SG (only if not in use)
  for sg in $(printf "%s\n" "${SG_TO_CLEAN[@]}" | sort -u); do
    read -r -p "Attempt delete security group $sg? (will fail if still in use) [y/N] " delsg
    case "$delsg" in
      [Yy]* )
        echo "Deleting SG $sg..."
        if aws ec2 delete-security-group --group-id "$sg" >/dev/null 2>&1; then
          echo "Deleted SG $sg"
        else
          echo "Failed to delete SG $sg (likely still in use). Run 'aws ec2 describe-security-groups --group-ids $sg' to inspect."
        fi
        ;;
      * )
        echo "Skipping SG $sg"
        ;;
    esac
  done
else
  echo "No endpoint security groups were discovered."
fi

echo
echo "Done. Re-run the Resource Groups Tagging API to confirm vpce ARNs are gone:"
echo "aws resourcegroupstaggingapi get-resources --region <region> --tag-filters Key=Project,Values=$PROJECT --query 'ResourceTagMappingList[].ResourceARN' --output text"