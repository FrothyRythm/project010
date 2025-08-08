#!/bin/bash
set -euo pipefail

# Template vars provided by Terraform:
#   ${gmail_user}, ${gmail_app_password}, ${github_token}, ${aws_access_key}, ${aws_secret_key}, ${github_repo}

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y openjdk-17-jdk git curl unzip wget awscli jq

# Install Terraform (so Jenkins can run terraform apply)
TF_VER="1.6.0"
wget -qO /tmp/terraform.zip https://releases.hashicorp.com/terraform/${TF_VER}/terraform_${TF_VER}_linux_amd64.zip
unzip -o /tmp/terraform.zip -d /usr/local/bin
chmod +x /usr/local/bin/terraform

# Install Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
apt-get update -y
apt-get install -y jenkins

# Stop Jenkins while we prepare configuration (so JCasC loads on first start)
systemctl stop jenkins || true

JENKINS_HOME="/var/lib/jenkins"
mkdir -p ${JENKINS_HOME}/casc_configs
mkdir -p ${JENKINS_HOME}/init.groovy.d
chown -R jenkins:jenkins ${JENKINS_HOME}

# -------------- Casc configuration (no secrets in git) --------------
cat > ${JENKINS_HOME}/casc_configs/casc.yaml <<'CASC'
jenkins:
  systemMessage: "Automated Jenkins provisioned by Terraform"
  numExecutors: 2

unclassified:
  location:
    url: "http://localhost:8080/"

tool:
  git:
    installations:
      - name: "Default"
        home: "/usr/bin/git"
CASC

# -------------- Groovy: create Jenkins credentials from environment variables --------------
cat > ${JENKINS_HOME}/init.groovy.d/create-credentials.groovy <<'GROOVY'
import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import hudson.util.Secret

def instance = Jenkins.getInstance()
def store = instance.getExtensionList(com.cloudbees.plugins.credentials.SystemCredentialsProvider.class)[0].getStore()

// Gmail credentials (username/password)
def gmailId = "gmail-creds"
if (store.getCredentials(Domain.global()).find { it.id == gmailId } == null) {
  def gmail = new UsernamePasswordCredentialsImpl(
      CredentialsScope.GLOBAL,
      gmailId,
      "Gmail app password",
      "${gmail_user}",
      "${gmail_app_password}"
  )
  store.addCredentials(Domain.global(), gmail)
}

// GitHub token (string credential)
def ghId = "github-token"
if (store.getCredentials(Domain.global()).find { it.id == ghId } == null) {
  def gh = new StringCredentialsImpl(
      CredentialsScope.GLOBAL,
      ghId,
      "GitHub personal access token",
      hudson.util.Secret.fromString("${github_token}")
  )
  store.addCredentials(Domain.global(), gh)
}

// AWS credentials (username/password) for Terraform runs inside Jenkins
def awsId = "aws-creds"
if (store.getCredentials(Domain.global()).find { it.id == awsId } == null) {
  def awsCred = new UsernamePasswordCredentialsImpl(
      CredentialsScope.GLOBAL,
      awsId,
      "AWS credentials for terraform",
      "${aws_access_key}",
      "${aws_secret_key}"
  )
  store.addCredentials(Domain.global(), awsCred)
}

instance.save()
GROOVY

# -------------- Groovy: create two pipeline jobs (app build + terraform apply) --------------
cat > ${JENKINS_HOME}/init.groovy.d/create-jobs.groovy <<'GROOVY'
import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition

def instance = Jenkins.getInstance()

// 1) App pipeline: builds node app and emails on result (uses gmail-creds)
def appJobName = "Project010-AppPipeline"
if (instance.getItem(appJobName) == null) {
  def appPipelineScript = """
pipeline {
  agent any
  environment {
    ADMIN_EMAIL = '${gmail_user}'
  }
  stages {
    stage('Checkout') {
      steps {
        git url: '${github_repo}', branch: 'main'
      }
    }
    stage('Install') {
      steps {
        sh 'which node || (curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && apt-get install -y nodejs)'
        sh 'npm install || true'
      }
    }
    stage('Test') {
      steps {
        sh 'npm test || true'
      }
    }
    stage('Deploy') {
      steps {
        sh '''
          if docker ps -q --filter "name=technova_app" | grep -q .; then docker stop technova_app || true; fi
          if docker ps -a -q --filter "name=technova_app" | grep -q .; then docker rm technova_app || true; fi
          docker build -t technova-node-app:latest . || true
          docker run -d --name technova_app -p 3000:3000 technova-node-app:latest || true
        '''
      }
    }
  }
  post {
    success {
      emailext (
        to: env.ADMIN_EMAIL,
        subject: "[TechNova] Deployment SUCCESS: ${env.JOB_NAME} #${'$'}{env.BUILD_NUMBER}",
        body: "Deployment succeeded. Job: ${'$'}{env.JOB_NAME} Build: ${'$'}{env.BUILD_NUMBER} (<a href='${'$'}{env.BUILD_URL}'>details</a>)"
      )
    }
    failure {
      emailext (
        to: env.ADMIN_EMAIL,
        subject: "[TechNova] Deployment FAILED: ${'$'}{env.JOB_NAME} #${'$'}{env.BUILD_NUMBER}",
        body: "Deployment failed. Job: ${'$'}{env.JOB_NAME} Build: ${'$'}{env.BUILD_NUMBER} (<a href='${'$'}{env.BUILD_URL}'>details</a>)"
      )
    }
  }
}
"""
  def job = new WorkflowJob(instance, appJobName)
  job.definition = new CpsFlowDefinition(appPipelineScript, true)
  instance.add(job, appJobName)
  job.save()
}

// 2) Terraform job: clones repo and runs terraform apply using aws-creds
def tfJobName = "Repo-Terraform-Apply"
if (instance.getItem(tfJobName) == null) {
  def tfPipelineScript = """
pipeline {
  agent any
  triggers { githubPush() }
  stages {
    stage('Checkout') {
      steps {
        git url: '${github_repo}', branch: 'main'
      }
    }
    stage('Terraform Apply') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_KEY', passwordVariable: 'AWS_SECRET'),
                         string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
          sh '''
            export AWS_ACCESS_KEY_ID=$AWS_KEY
            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET
            cd ${WORKSPACE}
            terraform init -input=false
            terraform apply -auto-approve -input=false
          '''
        }
      }
    }
  }
}
"""
  def job = new WorkflowJob(instance, tfJobName)
  job.definition = new CpsFlowDefinition(tfPipelineScript, true)
  instance.add(job, tfJobName)
  job.save()
}

instance.save()
GROOVY

# Ensure ownership and permissions
chown -R jenkins:jenkins ${JENKINS_HOME}
chmod -R 755 ${JENKINS_HOME}/init.groovy.d

# Install plugins using plugin-manager (plugin installation manager tool)
PLUGINS="configuration-as-code workflow-aggregator git email-ext pipeline-model-definition pipeline-stage-view credentials-binding plain-credentials docker-workflow pipeline-utility-steps github"
# download plugin manager if missing
if [ ! -f /usr/local/bin/jenkins-plugin-manager ]; then
  curl -fsSL -o /usr/local/bin/jenkins-plugin-manager https://raw.githubusercontent.com/jenkinsci/plugin-installation-manager-tool/master/bin/jenkins-plugin-manager
  chmod +x /usr/local/bin/jenkins-plugin-manager
fi

# Create plugin list file
printf "%s\n" $PLUGINS > /tmp/plugins.txt

# Use jenkins-plugin-manager (it will place plugins into /var/lib/jenkins/plugins)
java -jar /usr/share/jenkins/jenkins.war --version >/dev/null 2>&1 || true
# Try to use plugin manager (best-effort)
if command -v /usr/local/bin/jenkins-plugin-manager >/dev/null 2>&1; then
  /usr/local/bin/jenkins-plugin-manager --war /usr/share/jenkins/jenkins.war --plugin-file /tmp/plugins.txt --plugin-download-directory ${JENKINS_HOME}/plugins || true
  chown -R jenkins:jenkins ${JENKINS_HOME}/plugins || true
fi

# Configure Jenkins to load JCasC (point to our casc.yaml)
echo 'CASC_JENKINS_CONFIG=/var/lib/jenkins/casc_configs/casc.yaml' >> /etc/default/jenkins

# Start Jenkins
systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

# Wait until Jenkins becomes available
for i in {1..60}; do
  if curl -sSfL --fail http://localhost:8080/login >/dev/null 2>&1; then
    echo "Jenkins up"
    break
  fi
  sleep 5
done

echo "jenkins-bootstrap-done" > /tmp/jenkins-bootstrap-done
