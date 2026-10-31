# EWB AWS VPC Peering: Terraform + Ansible

Terraform builds the network (workbook pages 3-10). Ansible runs the tests (pages 8, 11)
and saves the real output in `ansible/evidence/`. Run it yourself: the report must show
YOUR execution results, with your own resource IDs.

## Prerequisites (laptop or WSL)
- Terraform >= 1.5, AWS CLI (configured: `aws sts get-caller-identity` works), ansible-core, OpenSSH
- Lab account with VPC + EC2 permissions. Cost: 3 x t3.micro + 1 public IPv4. Destroy when done.

## Stage 0: key and variables
```bash
# Private key stays on your laptop. Only the .pub file is sent to AWS.
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ewb-lab.pem -N ""
chmod 400 ~/.ssh/ewb-lab.pem

cd terraform
cp terraform.tfvars.example terraform.tfvars
echo "$(curl -s https://checkip.amazonaws.com)/32"     # paste into my_ip_cidr
# edit terraform.tfvars: student_name, my_ip_cidr  (leave enable_peering = false)
terraform init && terraform validate
```

## Stage 1: VPCs, subnets, routes, SGs, instances  (Checkpoints 01, 02)
```bash
terraform apply            # review the plan, type yes
terraform output           # instance IDs, private IPs, bastion public IP, network IDs
cd ../ansible
ssh -F ssh_config ewb-bastion          # type exit
ssh -F ssh_config ewb-app-a            # type exit  (works before peering)
ansible-playbook 01_baseline.yml       # Test 01: baseline FAILS (expected)
```
Console screenshots now: subnets list, `ewb-rt-a-public` + `ewb-rt-a-private` (routes and
subnet associations), the 3 security groups' inbound rules, instance list, App-A / App-B
detail pages with Public IPv4 empty.

## Stage 2: peering and routes  (Checkpoints 03, 04)
```bash
cd ../terraform
# edit terraform.tfvars: enable_peering = true
terraform apply
terraform output network_ids           # now includes the pcx-... ID
```
Console screenshots: `ewb-a-b-peer` Active with both VPC IDs, all three route tables
(with the new pcx routes and associations).

## Stage 3: prove it works  (Tests 02-05)
```bash
cd ../ansible
ansible-playbook 02_verify.yml         # forward ping, reverse ping, no public IP
ssh -F ssh_config ewb-app-b            # Test 04: shell on App-B via bastion (screenshot, then exit)
```

## Stage 4: controlled failure
```bash
ansible-playbook 03_controlled_failure.yml
```
Removes only the App-B echo rule, shows the ping fail, restores the exact rule, shows recovery.
Screenshot the App-B security group inbound rules at each state too.

## Stage 5: cleanup (do this LAST, after all evidence is saved)
```bash
cd ../terraform && terraform destroy   # type yes
cd .. && ./verify_cleanup.sh ap-south-1   # every line must say NONE; screenshot it
rm ~/.ssh/ewb-lab.pem ~/.ssh/ewb-lab.pem.pub
```

## Troubleshooting
| Symptom | Cause / fix |
|---|---|
| Bastion SSH times out | Your public IP changed. Update `my_ip_cidr`, `terraform apply` |
| `01_baseline.yml` assertion fails on ping | Peering is already enabled. Set `enable_peering = false` and apply |
| Ping fails after peering | Check all 3 pcx routes, peering Active, App-B echo rule present |
| Terraform: key file not found | Run Stage 0 `ssh-keygen`, or fix `public_key_path` |
| Instance type not offered | Change `instance_type` (instructor-approved small x86) |

## Notes for the report / viva
- `auto_accept = true` is the workbook's "Accept request" step for same-account, same-Region peering.
- Terraform removes the default allow-all outbound rule, so outbound is declared explicitly to match the workbook.
- The bastion's subnet needs the `10.20.0.0/16 -> pcx` route because ProxyJump makes the bastion open the SSH connection to App-B.
