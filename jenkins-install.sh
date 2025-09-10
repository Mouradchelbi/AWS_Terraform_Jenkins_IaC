#!/bin/bash
set -e
exec > /var/log/jenkins-install.log 2>&1

echo "Starting Jenkins installation $(date)"

apt update -y
apt install -y openjdk-17-jre curl unzip git wget

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws/

mkdir -p /etc/apt/keyrings
wget -O /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list

apt update -y
apt install -y jenkins

systemctl stop jenkins
sleep 5

if [ ! -f /swapfile ]; then
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

mkdir -p /var/lib/jenkins/casc_configs
mkdir -p /var/lib/jenkins/init.groovy.d

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

cat > /var/lib/jenkins/casc_configs/jenkins.yaml << 'YAML_END'
jenkins:
  systemMessage: "Jenkins configured with JCasC"
  numExecutors: 2
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: "admin"
          name: "Administrator"
          password: "admin123"
        - id: "developer"
          name: "Developer"
          password: "dev123"
  authorizationStrategy:
    globalMatrix:
      permissions:
        - "Overall/Administer:admin"
        - "Overall/Read:authenticated"
        - "Job/Build:developer"
        - "Job/Read:developer"
unclassified:
  location:
    adminAddress: "admin@jenkins.local"
tool:
  git:
    installations:
      - name: "Default"
        home: "/usr/bin/git"
YAML_END

cat > /var/lib/jenkins/init.groovy.d/setup.groovy << 'GROOVY_END'
import jenkins.model.*
import jenkins.install.*
Jenkins.getInstance().setInstallState(InstallState.INITIAL_SETUP_COMPLETED)
Jenkins.getInstance().save()
GROOVY_END

chown -R jenkins:jenkins /var/lib/jenkins

cat >> /etc/default/jenkins << 'JENKINS_END'
JAVA_ARGS="-Xmx512m -Xms256m"
CASC_JENKINS_CONFIG=/var/lib/jenkins/casc_configs
JAVA_OPTS="-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false"
JENKINS_END

systemctl enable jenkins
systemctl start jenkins

echo "Waiting for Jenkins startup"
sleep 120

if command -v aws; then
  INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  SECURITY_GROUP_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)
  aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0 || true
fi

echo "Jenkins installation complete"
echo "URL: http://$PUBLIC_IP:8080"
echo "Admin: admin / admin123"
echo "Developer: developer / dev123"
echo "Installation finished $(date)"