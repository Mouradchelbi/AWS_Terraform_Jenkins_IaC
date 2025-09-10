# AWS_Terraform_Jenkins_IaC

# Simplified Jenkins Installation Script Workflow

## Overview

The simplified jenkins-install.sh script performs a basic Jenkins installation without JCasC configuration, eliminating complexity and encoding issues.

## Phase 1: System Initialization (0-30 seconds)

### 1.1 Script Setup

```bash
set -e                           # Exit on any error
exec > /var/log/jenkins-install.log 2>&1  # Log all output
echo "Starting Jenkins installation $(date)"
```

- **Purpose**: Initialize error handling and logging
- **Output**: All commands logged to `/var/log/jenkins-install.log`

## Phase 2: System Dependencies (30-90 seconds)

### 2.1 Package Installation

```bash
apt update -y                    # Update package lists
apt install -y openjdk-17-jre curl unzip git
```

- **Purpose**: Install essential packages for Jenkins
- **Dependencies**:
  - `openjdk-17-jre`: Java runtime for Jenkins
  - `curl/unzip`: Download and extraction tools
  - `git`: Version control (commonly needed)

### 2.2 AWS CLI Installation

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws/
```

- **Purpose**: Install AWS CLI for security group management
- **No Retry Logic**: Simplified approach, fails fast if network issues

## Phase 3: Jenkins Repository Setup (90-120 seconds)

### 3.1 Repository Configuration

```bash
mkdir -p /etc/apt/keyrings
wget -O /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
```

- **Purpose**: Add official Jenkins repository with GPG verification
- **Security**: Package authenticity verification

### 3.2 Jenkins Installation

```bash
apt update -y
apt install -y jenkins
```

- **Purpose**: Install Jenkins package from official repository

## Phase 4: System Optimization (120-150 seconds)

### 4.1 Swap Configuration

```bash
if [ ! -f /swapfile ]; then
  fallocate -l 1G /swapfile      # Create 1GB swap file
  chmod 600 /swapfile            # Secure permissions
  mkswap /swapfile               # Format as swap
  swapon /swapfile               # Enable immediately
  echo '/swapfile none swap sw 0 0' >> /etc/fstab  # Make permanent
fi
```

- **Purpose**: Prevent out-of-memory issues on t2.micro
- **Size**: Fixed 1GB (suitable for t2.micro instances)
- **Persistence**: Survives reboots via fstab entry

### 4.2 Memory Optimization

```bash
echo 'JAVA_ARGS="-Xmx512m -Xms256m"' >> /etc/default/jenkins
```

- **Purpose**: Optimize Java heap size for t2.micro (1GB RAM)
- **Settings**: 512MB max heap, 256MB initial heap

## Phase 5: Service Startup (150-270 seconds)

### 5.1 Jenkins Service Start

```bash
systemctl enable jenkins         # Enable auto-start on boot
systemctl start jenkins          # Start Jenkins service
```

- **Purpose**: Start Jenkins with system integration

### 5.2 Initialization Wait

```bash
echo "Waiting for Jenkins to start"
sleep 120                       # Fixed 2-minute wait
```

- **Purpose**: Allow Jenkins to fully initialize
- **Duration**: 120 seconds (appropriate for t2.micro)
- **No Intelligence**: Simple fixed delay

## Phase 6: Network Configuration (270-300 seconds)

### 6.1 Security Group Configuration

```bash
if command -v aws; then
  INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  SECURITY_GROUP_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)
  aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0 || true
fi
```

- **Purpose**: Open port 8080 for Jenkins web interface
- **CIDR**: 0.0.0.0/0 (open to all - should be restricted in production)
- **Error Handling**: `|| true` prevents script failure if rule exists

## Phase 7: Completion and Output (300-310 seconds)

### 7.1 Final Status Report

```bash
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Jenkins installation complete"
echo "URL: http://$PUBLIC_IP:8080"
echo "Access Jenkins and follow the setup wizard"
echo "Initial password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo "Installation finished $(date)"
```

- **Purpose**: Provide access information to user
- **Manual Setup**: User must complete setup wizard manually

## Simplified Workflow Summary

| Phase | Duration | Activities                          | Notes                     |
| ----- | -------- | ----------------------------------- | ------------------------- |
| 1     | 0-30s    | Script initialization and logging   | Basic error handling only |
| 2     | 30-90s   | System packages and AWS CLI         | No retry mechanisms       |
| 3     | 90-120s  | Jenkins repository and installation | Standard apt installation |
| 4     | 120-150s | Swap and memory optimization        | Fixed configurations      |
| 5     | 150-270s | Service startup and wait            | Simple 2-minute delay     |
| 6     | 270-300s | Security group configuration        | Basic network setup       |
| 7     | 300-310s | Status reporting                    | Manual setup required     |

**Total Execution Time**: Approximately 5 minutes
**Manual Steps Required**:

- Get initial password via SSH
- Complete Jenkins setup wizard
- Install plugins manually
- Create admin user through web interface
