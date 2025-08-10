#!/bin/bash
set -e

GITHUB_REPO_URL="${github_repo_url}"
GITHUB_TOKEN="${github_token}"
GMAIL_USER="${gmail_user}"
GMAIL_PASS="${gmail_app_password}"
JENKINS_USER="${jenkins_admin_user}"
JENKINS_PASS="${jenkins_admin_password}"
TF_VER="${TF_VER}"

yum update -y
amazon-linux-extras enable java-openjdk11
yum install -y java-11-openjdk git wget unzip jq

wget https://releases.hashicorp.com/terraform/${TF_VER}/terraform_${TF_VER}_linux_amd64.zip
unzip terraform_${TF_VER}_linux_amd64.zip
mv terraform /usr/local/bin/
chmod +x /usr/local/bin/terraform

wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
yum install -y jenkins
systemctl enable jenkins
systemctl start jenkins

echo "Waiting for Jenkins to start..."
sleep 40

mkdir -p /var/lib/jenkins/init.groovy.d
cat <<EOF > /var/lib/jenkins/init.groovy.d/basic-security.groovy
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("${jenkins_admin_user}", "${jenkins_admin_password}")
instance.setSecurityRealm(hudsonRealm)
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
instance.setAuthorizationStrategy(strategy)
instance.save()
EOF

chown -R jenkins:jenkins /var/lib/jenkins/init.groovy.d

systemctl restart jenkins
sleep 40

mkdir -p /var/lib/jenkins/jobs/AutoPipeline
cat <<EOF > /var/lib/jenkins/jobs/AutoPipeline/config.xml
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <actions/>
  <description>Auto-created pipeline</description>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>${github_repo_url}</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
  </definition>
  <triggers>
    <hudson.triggers.SCMTrigger>
      <spec>* * * * *</spec>
    </hudson.triggers.SCMTrigger>
  </triggers>
</flow-definition>
EOF

chown -R jenkins:jenkins /var/lib/jenkins/jobs

cat <<EOF > /var/lib/jenkins/hudson.tasks.Mailer.xml
<?xml version='1.1' encoding='UTF-8'?>
<hudson.tasks.Mailer_-DescriptorImpl>
  <smtpHost>smtp.gmail.com</smtpHost>
  <smtpPort>587</smtpPort>
  <useSsl>false</useSsl>
  <authUsername>${gmail_user}</authUsername>
  <authPassword>${gmail_app_password}</authPassword>
</hudson.tasks.Mailer_-DescriptorImpl>
EOF

chown jenkins:jenkins /var/lib/jenkins/hudson.tasks.Mailer.xml

systemctl restart jenkins
