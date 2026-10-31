#!/usr/bin/env bash
# Run AFTER `terraform destroy`. Every section should print NONE.
# Usage: ./verify_cleanup.sh [region]
set -u
export AWS_PAGER=""
R="${1:-ap-south-1}"
TAG="Name=tag:Project,Values=EWB-VPC-Peering"

show() {  # show <title> <aws output>
  printf '%-22s : ' "$1"
  if [ -z "$2" ] || [ "$2" = "None" ]; then echo "NONE"; else echo "$2"; fi
}

show "EC2 instances" "$(aws ec2 describe-instances --region "$R" --filters "$TAG" \
  "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down" \
  --query 'Reservations[].Instances[].InstanceId' --output text)"
show "EBS volumes" "$(aws ec2 describe-volumes --region "$R" --filters "$TAG" \
  --query 'Volumes[].VolumeId' --output text)"
show "Elastic IPs" "$(aws ec2 describe-addresses --region "$R" --filters "$TAG" \
  --query 'Addresses[].AllocationId' --output text)"
show "Peering connections" "$(aws ec2 describe-vpc-peering-connections --region "$R" --filters "$TAG" \
  "Name=status-code,Values=active,pending-acceptance,provisioning,initiating-request" \
  --query 'VpcPeeringConnections[].VpcPeeringConnectionId' --output text)"
show "Security groups" "$(aws ec2 describe-security-groups --region "$R" --filters "$TAG" \
  --query 'SecurityGroups[].GroupId' --output text)"
show "Route tables" "$(aws ec2 describe-route-tables --region "$R" --filters "$TAG" \
  --query 'RouteTables[].RouteTableId' --output text)"
show "Subnets" "$(aws ec2 describe-subnets --region "$R" --filters "$TAG" \
  --query 'Subnets[].SubnetId' --output text)"
show "Internet gateways" "$(aws ec2 describe-internet-gateways --region "$R" --filters "$TAG" \
  --query 'InternetGateways[].InternetGatewayId' --output text)"
show "VPCs" "$(aws ec2 describe-vpcs --region "$R" --filters "$TAG" \
  --query 'Vpcs[].VpcId' --output text)"
show "Key pair ewb-lab" "$(aws ec2 describe-key-pairs --region "$R" --filters "Name=key-name,Values=ewb-lab" \
  --query 'KeyPairs[].KeyName' --output text 2>/dev/null)"
echo
echo "Also delete the local key if no longer needed:  rm ~/.ssh/ewb-lab.pem ~/.ssh/ewb-lab.pem.pub"
