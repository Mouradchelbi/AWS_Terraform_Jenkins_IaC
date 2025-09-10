# AWS_Terraform_Jenkins_IaC

## Overview

This project provides automated Infrastructure as Code (IaC) for deploying a Jenkins server on AWS using **Terraform**. The deployment is streamlined using a simplified `jenkins-install.sh` user data script that bootstraps Jenkins, manages system optimization for low-memory instances, installs dependencies, and configures network access for the Jenkins web interface.

---

## Jenkins Installation Script Workflow

### Key Features

- End-to-end AWS setup with Terraform (VPC, subnet, security group, EC2)
- Jenkins is fully installed and started on EC2 via the user data script
- Automated port access using AWS CLI from within the instance
- Optimized for low-memory instances (e.g., t2.micro) with swap and JVM tuning
- All installation steps and errors logged for easy debugging

---

## Workflow Phases

| Phase | Duration | Key Activities                        | Notes                                  |
| ----- | -------- | ------------------------------------- | -------------------------------------- |
| 1     | 0-30s    | Script setup, logging                 | Logs to `/var/log/jenkins-install.log` |
| 2     | 30-90s   | Install base packages and AWS CLI     | Java, curl, unzip, git, awscli         |
| 3     | 90-120s  | Configure Jenkins repository, install | Offical repo and GPG key               |
| 4     | 120-150s | Swap creation, JVM memory tuning      | Handle t2.micro limitations            |
| 5     | 150-270s | Start Jenkins, delay for init         | 2-min wait for service ready           |
| 6     | 270-300s | Open port 8080 in AWS security group  | Uses instance metadata, AWS CLI        |
| 7     | 300-310s | Print access info and completion      | URL, password retrieval shown          |

**Total Execution Time:** ~5 minutes

---

## Requirements

- AWS account and credentials configured (`aws configure`)
- Terraform 1.0+ and AWS CLI installed
- Valid EC2 key pair for SSH access
- Git (for cloning this repo)

---

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR-USERNAME/AWS_Terraform_Jenkins_IaC.git
cd AWS_Terraform_Jenkins_IaC/jenkins-terraform
```

### 2. Initialize and Configure Terraform

```bash
terraform init
# (Edit terraform.tfvars or variables as needed)
```

Common variables:

```hcl
vpc_cidr              = "10.0.0.0/16"
public_subnet         = ["10.0.1.0/24"]
jenkins_instance_type = "t2.micro"
key_name              = "your-ec2-keypair"
```

### 3. Deploy the Stack

```bash
terraform apply
```

- Review and approve the plan.
- Terraform provisions all infra and bootstraps Jenkins via user data.

---

## Accessing Jenkins

- Find the EC2 public IP in Terraform output or AWS Console.
- Visit: `http://<PUBLIC_IP>:8080`
- To complete setup, SSH into the instance and retrieve the initial admin password:

```bash
ssh -i your-key.pem ubuntu@<PUBLIC_IP>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

- Finish the setup wizard in the web UI.

---

## The jenkins-install.sh User Data Script

The script automatically:

- Installs Java, AWS CLI, curl, unzip, git
- Configures the Jenkins apt repo and GPG key
- Installs Jenkins
- Creates a 1GB swap file for RAM-constrained EC2
- Tunes the Jenkins JVM heap for t2.micro
- Starts Jenkins as a service
- Waits 2 minutes for Jenkins to initialize
- Uses AWS CLI to open TCP port 8080 in the instance’s security group
- Outputs public URL and instructions for manual setup

_All output is logged to `/var/log/jenkins-install.log` for troubleshooting._

---

## Manual Steps After Deployment

- SSH in and get the initial Jenkins password
- Complete the setup wizard in the browser
- Install desired plugins
- Create your admin user

---

## Security Considerations

- The script opens port 8080 to 0.0.0.0/0 (internet-wide); update the script or security group to restrict access in production
- For CI setup or automated Jenkins provisioning, extend the script or use a Configuration as Code approach
