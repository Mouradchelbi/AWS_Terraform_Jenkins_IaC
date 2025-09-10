# ============================================================================
# outputs.tf - Terraform Outputs for Jenkins Infrastructure
# ============================================================================

# ============================================================================
# Infrastructure Outputs
# ============================================================================
output "account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "AWS Region"
  value       = data.aws_region.current.name
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.jenkins_server.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.jenkins_server.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.jenkins_server.private_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.jenkins_server.public_dns
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.jenkins_sg.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role attached to the instance"
  value       = aws_iam_role.jenkins_ec2_role.arn
}

output "instance_profile_arn" {
  description = "ARN of the instance profile"
  value       = aws_iam_instance_profile.jenkins_profile.arn
}

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = data.aws_ami.ubuntu.id
}

output "vpc_id" {
  description = "VPC ID where the instance is deployed"
  value       = data.aws_vpc.selected.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = data.aws_vpc.selected.cidr_block
}

output "subnet_id" {
  description = "Subnet ID where the instance is deployed"
  value       = data.aws_subnets.available.ids[0]
}

# ============================================================================
# Jenkins Access Outputs
# ============================================================================
output "jenkins_url" {
  description = "URL to access Jenkins"
  value       = "http://${aws_instance.jenkins_server.public_ip}:8080"
}

output "jenkins_admin_user" {
  description = "Jenkins admin username"
  value       = "admin"
}

output "jenkins_admin_password" {
  description = "Jenkins admin password"
  value       = "admin123"
  sensitive   = true
}

output "jenkins_developer_user" {
  description = "Jenkins developer username"
  value       = "developer"
}

output "jenkins_developer_password" {
  description = "Jenkins developer password"
  value       = "dev123"
  sensitive   = true
}

# ============================================================================
# SSH and Management Commands
# ============================================================================
output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.jenkins_server.public_ip}"
}

output "jenkins_initial_password_command" {
  description = "Command to retrieve initial Jenkins password (backup)"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.jenkins_server.public_ip} 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'"
}

output "jenkins_log_command" {
  description = "Command to view Jenkins installation logs"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.jenkins_server.public_ip} 'sudo cat /var/log/jenkins-install.log'"
}

output "jenkins_service_status_command" {
  description = "Command to check Jenkins service status"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.jenkins_server.public_ip} 'sudo systemctl status jenkins'"
}

output "jenkins_restart_command" {
  description = "Command to restart Jenkins service"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.jenkins_server.public_ip} 'sudo systemctl restart jenkins'"
}

# ============================================================================
# Jenkins Configuration Information
# ============================================================================
output "jenkins_configuration_location" {
  description = "Location of Jenkins Configuration as Code files"
  value       = "/var/lib/jenkins/casc_configs/jenkins.yaml"
}

output "jenkins_features" {
  description = "Jenkins features and configuration status"
  value = {
    jcasc_enabled     = true
    setup_wizard      = "skipped"
    security_enabled  = true
    plugins_installed = "automatically"
    memory_optimized  = "t2.micro"
  }
}

output "jenkins_sample_jobs" {
  description = "Pre-created Jenkins jobs"
  value = [
    "sample-pipeline",
    "ci-cd-pipelines/terraform-pipeline"
  ]
}

# ============================================================================
# Complete Login Instructions
# ============================================================================
output "jenkins_login_instructions" {
  description = "Complete instructions for accessing Jenkins"
  value = <<-EOT
    ================================
    Jenkins Access Instructions
    ================================
    
    URL: http://${aws_instance.jenkins_server.public_ip}:8080
    
    Login Credentials:
    - Admin User: admin / admin123
    - Developer User: developer / dev123
    
    Features:
    - Setup wizard automatically skipped
    - Configuration as Code (JCasC) enabled
    - Essential plugins pre-installed
    - Sample jobs ready to run
    
    Sample Jobs Created:
    - sample-pipeline (Basic pipeline example)
    - ci-cd-pipelines/terraform-pipeline (Terraform template)
    
    ================================
    Ready to use immediately!
    ================================
  EOT
}

# ============================================================================
# Quick Access Commands
# ============================================================================
output "quick_access_commands" {
  description = "Quick access commands for Jenkins management"
  value = {
    # Browser access
    open_jenkins_url = "http://${aws_instance.jenkins_server.public_ip}:8080"
    
    # SSH access
    ssh_to_instance = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.jenkins_server.public_ip}"
    
    # Health checks
    check_jenkins_http = "curl -I http://${aws_instance.jenkins_server.public_ip}:8080"
    check_jenkins_service = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.jenkins_server.public_ip} 'sudo systemctl status jenkins'"
    
    # Log viewing
    view_install_logs = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.jenkins_server.public_ip} 'sudo cat /var/log/jenkins-install.log'"
    view_jenkins_logs = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.jenkins_server.public_ip} 'sudo journalctl -u jenkins -f'"
    
    # Management
    restart_jenkins = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.jenkins_server.public_ip} 'sudo systemctl restart jenkins'"
    stop_jenkins = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.jenkins_server.public_ip} 'sudo systemctl stop jenkins'"
    start_jenkins = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.jenkins_server.public_ip} 'sudo systemctl start jenkins'"
  }
}

# ============================================================================
# Deployment Summary
# ============================================================================
output "deployment_summary" {
  description = "Complete deployment summary"
  value = {
    # Project Information
    project_name = var.project_name
    environment  = var.environment
    region      = var.aws_region
    created_by  = "terraform-user"
    managed_by  = "Terraform"
    
    # Infrastructure Details
    instance_id     = aws_instance.jenkins_server.id
    instance_type   = var.instance_type
    vpc_id         = data.aws_vpc.selected.id
    vpc_cidr       = data.aws_vpc.selected.cidr_block
    subnet_id      = data.aws_subnets.available.ids[0]
    security_group = aws_security_group.jenkins_sg.id
    
    # Jenkins Details
    jenkins_url             = "http://${aws_instance.jenkins_server.public_ip}:8080"
    jenkins_admin_login     = "admin / admin123"
    jenkins_developer_login = "developer / dev123"
    jenkins_jcasc_enabled   = true
    jenkins_setup_wizard    = "automatically skipped"
    
    # Access Information
    ssh_access = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.jenkins_server.public_ip}"
    
    # Status
    deployment_status = "complete"
    ready_to_use     = true
  }
}

# ============================================================================
# Cost and Resource Information
# ============================================================================
output "cost_information" {
  description = "Estimated cost and resource information"
  value = {
    instance_type = var.instance_type
    storage_size  = "${var.volume_size}GB"
    storage_type  = "gp3"
    estimated_monthly_cost = "~$8-10 USD (if running 24/7)"
    cost_optimization_tips = [
      "Stop instance when not in use",
      "Use scheduled start/stop",
      "Monitor with CloudWatch",
      "Consider spot instances for dev"
    ]
  }
}