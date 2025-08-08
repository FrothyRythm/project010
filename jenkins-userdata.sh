#!/bin/bash
set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

# Simple bootstrap for Jenkins on Amazon Linux 2023
# Installs: Java (Corretto), Docker, downloads jenkins.war and runs it as a systemd service

# Update and install utilities
dnf install -y curl wget git unzip python3 jq

# Install Java (Amazon Corretto 17)
dnf install -y java-17-amazon-corretto-devel

# Create jenkins user and proper home (use /var/lib/jenkins as JENKINS_HOME)
useradd -m -d /var/lib/jenkins -s /bin/bash jenkins || true
mkdir -p /var/lib/jenkins
chown -R jenkins:jenkins /var/lib/jenkins
chmod 755 /var/lib/jenkins

# Download Jenkins war to /opt/jenkins
mkdir -p /opt/jenkins
curl -L -o /opt/jenkins/jenkins.war https://get.jenkins.io/war-stable/latest/jenkins.war
chown -R jenkins:jenkins /opt/jenkins
chmod 755 /opt/jenkins/jenkins.war

# Create systemd service that sets JENKINS_HOME to /var/lib/jenkins and disables setup wizard
cat <<'EOT' > /etc/systemd/system/jenkins-custom.service
[Unit]
Description=Custom Jenkins CI Server
After=network.target

[Service]
User=jenkins
Group=jenkins
WorkingDirectory=/var/lib/jenkins
Environment=JENKINS_HOME=/var/lib/jenkins
ExecStart=/usr/bin/java -DJENKINS_HOME=/var/lib/jenkins -Djenkins.install.runSetupWizard=false -Djava.awt.headless=true -Xms256m -Xmx512m -jar /opt/jenkins/jenkins.war
Restart=always

[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable jenkins-custom
systemctl start jenkins-custom

# Install Docker
dnf install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker jenkins
usermod -aG docker ec2-user || true

# Wait for Jenkins to come up
sleep 30

# Create init.groovy.d and write configuration scripts
mkdir -p /var/lib/jenkins/init.groovy.d
chown -R jenkins:jenkins /var/lib/jenkins/init.groovy.d
chmod 755 /var/lib/jenkins/init.groovy.d

# 1) Plugin installer + admin user + basic mailer + job creation
cat <<'GROOVY' > /var/lib/jenkins/init.groovy.d/00-bootstrap.groovy
import jenkins.model.*
import hudson.security.*
import java.util.logging.Logger
import hudson.util.PluginServletFilter
import jenkins.install.InstallState

def logger = Logger.getLogger("")

// Ensure Jenkins doesn't think it's not fully installed
Jenkins.instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)

// Install required plugins if not present
def pm = Jenkins.instance.pluginManager
def uc = Jenkins.instance.updateCenter

def required = [
  'git',
  'workflow-aggregator',
  'pipeline-github-lib',
  'docker-workflow',
  'mailer',
  'email-ext'
]

required.each { pluginId ->
  if (!pm.getPlugin(pluginId)) {
    logger.info("Installing plugin: ${pluginId}")
    def pl = uc.getPlugin(pluginId)
    if (pl) {
      pl.deploy()
    }
  }
}

// Create admin user if not exists
def instance = Jenkins.get()
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
if (instance.getSecurityRealm() == null || instance.getSecurityRealm() instanceof hudson.security.SecurityRealm) {
  // Only create if no security realm configured
  instance.setSecurityRealm(hudsonRealm)
  hudsonRealm.createAccount('admin','admin123')
  def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
  instance.setAuthorizationStrategy(strategy)
  instance.save()
}
GROOVY

# 2) Mail configuration (PLACEHOLDERS - replace with your SMTP settings after instance created or modify here)
cat <<'GROOVY' > /var/lib/jenkins/init.groovy.d/10-mailer.groovy
import jenkins.model.Jenkins
import hudson.tasks.Mailer

// -- EDIT THE VALUES BELOW to match your SMTP server --
def smtpHost = "smtp.gmail.com" 
def smtpPort = "587"
def smtpUser = "kshitijsinha1002@gmail.com" 
def smtpPassword = "hjsh udio qaih zbdr"
def adminEmail = "kshitijsinha1002@gmail.com" 

def inst = Jenkins.instance
inst.getDescriptorByType(hudson.tasks.Mailer.DescriptorImpl.class).setSmtpHost(smtpHost)
inst.getDescriptorByType(hudson.tasks.Mailer.DescriptorImpl.class).setSmtpPort(smtpPort)
inst.getDescriptorByType(hudson.tasks.Mailer.DescriptorImpl.class).setUseSsl(false)
inst.getDescriptorByType(hudson.tasks.Mailer.DescriptorImpl.class).setReplyToAddress(adminEmail)
inst.save()

// You can add code here to create credentials for SMTP if your mail server needs authentication (not covered here)
GROOVY

# 3) Create pipeline job pointing to your GitHub repo
cat <<'GROOVY' > /var/lib/jenkins/init.groovy.d/20-create-job.groovy
import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import hudson.plugins.git.GitSCM
import hudson.plugins.git.BranchSpec
import hudson.plugins.git.extensions.impl.CloneOption
import hudson.model.Result

def jenkins = Jenkins.instance

def jobName = "TechNova-NodeJS-Auto-Deploy"
if (jenkins.getItem(jobName) == null) {
  println "Creating job: ${jobName}"
  def job = new WorkflowJob(jenkins, jobName)

  // The repository - modify if you want different repo
  def repoUrl = "https://github.com/FrothyRythm/project010.git"
  def scm = new GitSCM(repoUrl)
  job.definition = new CpsScmFlowDefinition(scm, 'Jenkinsfile')
  jenkins.add(job, jobName)
  job.save()
}
GROOVY

chown -R jenkins:jenkins /var/lib/jenkins/init.groovy.d

# Provide a short marker file so user knows bootstrap completed
echo "jenkins-bootstrap-complete" > /tmp/jenkins-bootstrap-complete

# done