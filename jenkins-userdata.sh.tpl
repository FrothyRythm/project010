#!/bin/bash
set -e

# Update & install dependencies
yum update -y
yum install -y java-17-amazon-corretto git wget unzip

# Install Jenkins
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat/jenkins.io-2023.key
yum install -y jenkins

systemctl enable jenkins
systemctl start jenkins

# Wait for Jenkins to start
sleep 30

# Install Jenkins CLI
wget http://localhost:8080/jnlpJars/jenkins-cli.jar -O /tmp/jenkins-cli.jar

# Jenkins init setup
JENKINS_PASS=$(cat /var/lib/jenkins/secrets/initialAdminPassword)

# Install plugins
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ -auth admin:$JENKINS_PASS install-plugin git pipeline-utility-steps email-ext -deploy

# Create admin user
cat <<EOF | java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ groovy = --auth admin:$JENKINS_PASS
import jenkins.model.*
import hudson.security.*
def instance = Jenkins.getInstance()
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "admin123")
instance.setSecurityRealm(hudsonRealm)
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
instance.setAuthorizationStrategy(strategy)
instance.save()
EOF

# Create Pipeline job
cat <<EOF > /tmp/job_config.xml
<flow-definition plugin="workflow-job">
  <description>Automated pipeline</description>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>${github_repo}</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
</flow-definition>
EOF

java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ create-job MyPipeline < /tmp/job_config.xml --auth admin:admin123

# Send email notification (using ssmtp or mailx)
yum install -y mailx
echo "set smtp=smtp.gmail.com:587
set smtp-use-starttls
set smtp-auth=login
set smtp-auth-user=${gmail_user}
set smtp-auth-password=${gmail_app_password}
set ssl-verify=ignore
set nss-config-dir=/etc/pki/nssdb" > /etc/mail.rc

echo "Jenkins setup complete! URL: http://$(curl -s ifconfig.me):8080" | mail -s "Jenkins Deployment" ${gmail_user}
# Cleanup