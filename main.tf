# ============================================================================
# Terraform Configuration for AWS EC2 t2.micro Instance
# Uses dedicated terraform-user with least privilege permissions
# Fixed VPC selection to work with any available VPC
# ============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ============================================================================
# Provider Configuration with terraform-user profile
# ============================================================================
provider "aws" {
  region  = var.aws_region
  profile = "terraform-user"  # Uses the dedicated IAM user profile
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CreatedBy   = "terraform-user"
      Purpose     = "Jenkins-CI-CD"
    }
  }
}

# ============================================================================
# Variables - Must match terraform.tfvars
# ============================================================================
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition = contains([
      "us-east-1", "us-east-2", "us-west-1", "us-west-2",
      "eu-west-1", "eu-west-2", "eu-central-1"
    ], var.aws_region)
    error_message = "AWS region must be a valid region."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "jenkins-automation"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "DevOps-Team"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
  
  validation {
    condition = contains([
      "t2.nano", "t2.micro", "t2.small"
    ], var.instance_type)
    error_message = "Instance type must be t2.nano, t2.micro, or t2.small (as per IAM policy)."
  }
}

variable "key_pair_name" {
  description = "Name of the EC2 Key Pair for SSH access"
  type        = string
  
  validation {
    condition     = length(var.key_pair_name) > 0
    error_message = "Key pair name cannot be empty."
  }
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
  
  validation {
    condition = alltrue([
      for cidr in var.allowed_ssh_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "All entries must be valid CIDR blocks."
  }
}

variable "allowed_jenkins_cidrs" {
  description = "CIDR blocks allowed for Jenkins web access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
  
  validation {
    condition = alltrue([
      for cidr in var.allowed_jenkins_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "All entries must be valid CIDR blocks."
  }
}

variable "volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.volume_size >= 8 && var.volume_size <= 100
    error_message = "Volume size must be between 8 and 100 GB."
  }
}

# ============================================================================
# Local Values
# ============================================================================
locals {
  # Common naming convention
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Resource tags
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Owner       = var.owner
    CreatedBy   = "terraform-user"
  }
  
  # User data script with template variables
  user_data = base64encode(templatefile("${path.module}/jenkins-install.sh", {
    region      = var.aws_region
    environment = var.environment
    project     = var.project_name
  }))
}

# ============================================================================
# Data Sources - Updated to work with any available VPC
# ============================================================================
# Get the latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Get available VPCs
data "aws_vpcs" "available" {
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Use the first available VPC (could be default or any other VPC)
data "aws_vpc" "selected" {
  id = data.aws_vpcs.available.ids[0]
}

# Get subnets from the selected VPC
data "aws_subnets" "available" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Validate key pair exists
data "aws_key_pair" "selected" {
  key_name = var.key_pair_name
}

# ============================================================================
# Security Groups
# ============================================================================
# Security group for Jenkins server
resource "aws_security_group" "jenkins_sg" {
  name_prefix = "${local.name_prefix}-jenkins-"
  description = "Security group for Jenkins server - managed by terraform-user"
  vpc_id      = data.aws_vpc.selected.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-jenkins-sg"
    Type = "SecurityGroup"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# SSH access rule
resource "aws_security_group_rule" "jenkins_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ssh_cidrs
  description       = "SSH access for Jenkins server"
  security_group_id = aws_security_group.jenkins_sg.id
}

# Jenkins web interface rule
resource "aws_security_group_rule" "jenkins_web" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = var.allowed_jenkins_cidrs
  description       = "Jenkins web interface access"
  security_group_id = aws_security_group.jenkins_sg.id
}

# All outbound traffic rule
resource "aws_security_group_rule" "jenkins_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "All outbound traffic"
  security_group_id = aws_security_group.jenkins_sg.id
}

# ============================================================================
# IAM Role for EC2 Instance (Least Privilege)
# ============================================================================
# IAM role for EC2 instance to access AWS services
resource "aws_iam_role" "jenkins_ec2_role" {
  name_prefix = "${local.name_prefix}-ec2-"
  description = "IAM role for Jenkins EC2 instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ec2-role"
    Type = "IAMRole"
  })
}

# IAM policy for minimal EC2 permissions
resource "aws_iam_role_policy" "jenkins_ec2_policy" {
  name_prefix = "${local.name_prefix}-ec2-"
  role        = aws_iam_role.jenkins_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2InstanceMetadata"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeRegions",
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecurityGroupManagement"
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:Region" = var.aws_region
          }
        }
      },
      {
        Sid    = "STSIdentity"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance profile for the EC2 instance
resource "aws_iam_instance_profile" "jenkins_profile" {
  name_prefix = "${local.name_prefix}-"
  role        = aws_iam_role.jenkins_ec2_role.name

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-instance-profile"
    Type = "InstanceProfile"
  })
}

# ============================================================================
# EC2 Instance
# ============================================================================
resource "aws_instance" "jenkins_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name              = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins_profile.name
  
  # Use first available subnet
  subnet_id = data.aws_subnets.available.ids[0]
  
  # Ensure public IP is assigned
  associate_public_ip_address = true
  
  # Enable detailed monitoring
  monitoring = true
  
  # User data script for automated Jenkins installation
  user_data = local.user_data
  
  # Root volume configuration
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.volume_size
    encrypted             = true
    delete_on_termination = true
    
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-root-volume"
      Type = "EBSVolume"
    })
  }

  # Ensure instance is created after security group
  depends_on = [
    aws_security_group_rule.jenkins_ssh,
    aws_security_group_rule.jenkins_web,
    aws_security_group_rule.jenkins_egress
  ]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-jenkins-server"
    Type = "Jenkins-CI-CD-Server"
    AutoShutdown = "true"  # For cost optimization
  })

  # Wait for instance to be ready before considering creation complete
  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }

  # Prevent accidental termination in production
  disable_api_termination = var.environment == "prod" ? true : false
}

