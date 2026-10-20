#!/bin/bash

set -e

yum update -y

yum install -y htop vim git curl wget jq awscli tree unzip

yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

cat > /etc/motd << 'MOTDEOF'
===============================================
  ${project_name} ${environment} Bastion Host
===============================================

Quick commands:
- list-private-instances    # Show all private instances
- ssh-private <instance-id> # Connect to private instance
- aws ssm start-session --target <instance-id> # SSM access

===============================================
MOTDEOF

cat > /etc/logrotate.d/bastion-security << EOF
/var/log/secure {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

cat > /usr/local/bin/list-private-instances << 'EOF'
#!/bin/bash
VPC_ID=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/ | head -1)/vpc-id)
echo "Private instances in VPC: $VPC_ID"
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" "Name=vpc-id,Values=$VPC_ID" \
  --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],PrivateIpAddress,State.Name]' \
  --output table
EOF

cat > /usr/local/bin/ssh-private << 'EOF'
#!/bin/bash
if [ $# -eq 0 ]; then
    echo "Usage: ssh-private <instance-id> [ssh-options]"
    exit 1
fi

INSTANCE_ID=$1
shift

PRIVATE_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[*].Instances[*].PrivateIpAddress' \
  --output text)

if [ -z "$PRIVATE_IP" ]; then
    echo "Instance $INSTANCE_ID not found or no private IP"
    exit 1
fi

echo "Connecting to $INSTANCE_ID ($PRIVATE_IP)..."
ssh -i ~/.ssh/asign-bastion-key ec2-user@"$PRIVATE_IP" "$@"
EOF

chmod +x /usr/local/bin/list-private-instances /usr/local/bin/ssh-private

%{ if length(devops_ssh_keys) > 0 }
mkdir -p /opt/bastion
cat > /opt/bastion/append-devops-keys.sh << 'APPENDSCRIPT'
#!/bin/bash
set -e
KEYS_FILE="/home/ec2-user/.ssh/authorized_keys"
MARKER="# popcorn-devops-ssh-keys-v1"
if grep -qF "$MARKER" "$KEYS_FILE" 2>/dev/null; then
  exit 0
fi
mkdir -p /home/ec2-user/.ssh
chmod 700 /home/ec2-user/.ssh
touch "$KEYS_FILE"
{
  echo "$MARKER"
  cat << 'INNERKEYS'
%{ for key in devops_ssh_keys }
${key}
%{ endfor }
INNERKEYS
} >> "$KEYS_FILE"
chown -R ec2-user:ec2-user /home/ec2-user/.ssh
chmod 600 "$KEYS_FILE"
APPENDSCRIPT
chmod +x /opt/bastion/append-devops-keys.sh
( sleep 120 && /opt/bastion/append-devops-keys.sh ) >> /var/log/bastion-append-devops-keys.log 2>&1 &
echo "$(date): Scheduled DevOps SSH key append in ~120s (background)" >> /var/log/bastion-setup.log
%{ endif }

echo "$(date): Bastion setup completed" >> /var/log/bastion-setup.log