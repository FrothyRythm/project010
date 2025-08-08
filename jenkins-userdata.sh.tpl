#!/bin/bash
set -euo pipefail
exec > /var/log/jenkins-bootstrap.log 2>&1

echo "=== userdata start ==="
date

# Terraform-substituted values:
GITHUB_REPO='${github_repo_url}'
GITHUB_TOKEN='${github_token}'
GMAIL_USER='${gmail_user}'
GMAIL_APP_PASSWORD='${gmail_app_password}'
JENKINS_ADMIN_USER='${jenkins_admin_user}'
JENKINS_ADMIN_PASSWORD='${jenkins_admin_password}'
TERRAFORM_VERSION='${TF_VER}'

echo "Variables: repo=${GITHUB_REPO}"

# ---- helper: retry function ----
retry() {
  local n=1
  local max=5
  local delay=5
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        echo "Command failed. Retry #$n in $delay sec..."
        n=$((n+1))
        sleep $delay
      else
        echo "Command failed after $n attempts."
        return 1
      fi
    }
  done
}

# ---- update and prerequisite packages ----
if command -v yum >/dev/null 2>&1; then
  retry yum update -y
  retry yum install -y wget unzip git jq python3
else
  retry apt-get update -y
  retry apt-get install -y wget unzip git jq python3
fi

# ---- install java 11 ----
if command -v amazon-linux-extras >/dev/null 2>&1; then
  amazon-linux-extras enable java-openjdk11 || true
  retry yum install -y java-11-openjdk-devel || true
else
  retry apt-get install -y openjdk-11-jdk || true
fi

# ---- install terraform (for Jenkins usage) ----
TFBIN="/usr/local/bin/terraform"
if [ ! -x "$TFBIN" ]; then
  retry wget -qO /tmp/terraform.zip "https://releases.hashicorp.com/terraform/$${TERRAFORM_VERSION}/terraform_$${TERRAFORM_VERSION}_linux_amd64.zip"
  unzip -o /tmp/terraform.zip -d /usr/local/bin
  chmod +x /usr/local/bin/terraform || true
  rm -f /tmp/terraform.zip
fi

# ---- install aws cli v2 ----
if ! command -v aws >/dev/null 2>&1; then
  retry curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip || true
  unzip -o /tmp/awscliv2.zip -d /tmp/awscli || true
  /tmp/awscli/aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli || true
  rm -rf /tmp/awscliv2.zip /tmp/awscli || true
fi

# ---- install Jenkins ----
echo "Installing Jenkins..."
if [ -f /etc/os-release ] && grep -qi "amazon" /etc/os-release; then
  # Amazon Linux 2
  wget -q -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
  rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key || true
  retry yum install -y jenkins || true
else
  # Debian/Ubuntu fallback
  wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
  retry apt-get update -y
  retry apt-get install -y jenkins || true
fi

systemctl enable jenkins || true
systemctl start jenkins || true

# Wait for Jenkins HTTP to be available
echo "Waiting for Jenkins HTTP..."
for i in $(seq 1 60); do
  if curl -sS http://localhost:8080/login >/dev/null 2>&1; then
    echo "Jenkins is responding"
    break
  fi
  sleep 5
done

# Ensure Jenkins home exists
JENKINS_HOME="/var/lib/jenkins"
mkdir -p "${JENKINS_HOME}/init.groovy.d"
chown -R jenkins:jenkins "${JENKINS_HOME}" || true
chmod -R 755 "${JENKINS_HOME}/init.groovy.d" || true

# ---- Create credentials & admin & SMTP & pipeline via init groovy scripts ----

# 01 - create credentials (github token, aws creds will be left out if not provided)
cat > "${JENKINS_HOME}/init.groovy.d/01-create-credentials.groovy" <<GROOVY
import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import hudson.util.Secret

def instance = Jenkins.getInstance()
def store = instance.getExtensionList(com.cloudbees.plugins.credentials.SystemCredentialsProvider.class)[0].getStore()

// GitHub token
def ghId = "github-token"
if (store.getCredentials(Domain.global()).find { it.id == ghId } == null && "${GITHUB_TOKEN}"?.trim()) {
  def token = "${GITHUB_TOKEN}"
  def ghCred = new StringCredentialsImpl(CredentialsScope.GLOBAL, ghId, "GitHub token", hudson.util.Secret.fromString(token))
  store.addCredentials(Domain.global(), ghCred)
}

// Gmail creds (username/password) - stored as username/password so plugins can use
def gmailId = "gmail-creds"
if (store.getCredentials(Domain.global()).find { it.id == gmailId } == null) {
  def guser = "${GMAIL_USER}"
  def gpass = "${GMAIL_APP_PASSWORD}"
  def gmailCred = new UsernamePasswordCredentialsImpl(CredentialsScope.GLOBAL, gmailId, "Gmail app creds", guser, gpass)
  store.addCredentials(Domain.global(), gmailCred)
}

instance.save()
GROOVY

# 02 - Configure mail (SMTP)
cat > "${JENKINS_HOME}/init.groovy.d/02-configure-mail.groovy" <<GROOVY
import jenkins.model.*
def inst = Jenkins.getInstance()
def mailer = inst.getDescriptor("hudson.tasks.Mailer")
mailer.setSmtpHost("smtp.gmail.com")
mailer.setSmtpPort("587")
mailer.setUseSsl(false)
mailer.setReplyToAddress("${GMAIL_USER}")
mailer.setAdminAddress("${GMAIL_USER}")
try {
  mailer.setSmtpAuth(true)
  mailer.setSmtpUserName("${GMAIL_USER}")
  mailer.setSmtpPassword("${GMAIL_APP_PASSWORD}")
} catch(Exception e) {
  // ignore if methods not present
}
mailer.save()
inst.save()
GROOVY

# 03 - create admin and disable setup wizard
cat > "${JENKINS_HOME}/init.groovy.d/03-create-admin.groovy" <<GROOVY
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

def id = "${JENKINS_ADMIN_USER}"
def pw = "${JENKINS_ADMIN_PASSWORD}"

// If no HudsonPrivateSecurityRealm, create one and add user
def realm = instance.getSecurityRealm()
if (!(realm instanceof HudsonPrivateSecurityRealm)) {
  def hudsonRealm = new HudsonPrivateSecurityRealm(false)
  hudsonRealm.createAccount(id, pw)
  instance.setSecurityRealm(hudsonRealm)
}

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

def desc = instance.getDescriptor("jenkins.model.JenkinsLocationConfiguration")
desc.setAdminAddress("${GMAIL_USER}")
desc.save()

instance.save()
println("Admin user created: " + id)
GROOVY

# 04 - create pipeline job (uses Jenkinsfile in repo)
cat > "${JENKINS_HOME}/init.groovy.d/04-create-job.groovy" <<GROOVY
import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import hudson.plugins.git.*

def instance = Jenkins.getInstance()
def jobName = "Repo-Terraform-Auto"

if (instance.getItem(jobName) == null) {
  def gitUrl = "${GITHUB_REPO}"
  def scm = new GitSCM(
    [new UserRemoteConfig(gitUrl, null, null, null)],
    [new BranchSpec("*/main")],
    false, [], null, null, []
  )
  def job = new WorkflowJob(instance, jobName)
  job.definition = new CpsScmFlowDefinition(scm, "Jenkinsfile")
  instance.add(job, jobName)
  job.save()
  job.scheduleBuild2(0)
}
GROOVY

# Ensure ownership
chown -R jenkins:jenkins "${JENKINS_HOME}" || true

# Restart Jenkins to ensure init scripts applied
systemctl restart jenkins || true

# Wait for Jenkins to come back up
for i in $(seq 1 40); do
  if curl -sS http://localhost:8080/login >/dev/null 2>&1; then
    echo "Jenkins ready"
    break
  fi
  sleep 5
done

# ---- Create GitHub webhook automatically (requires GITHUB_TOKEN and repo path) ----
# Convert repo URL to owner/repo (strip https://github.com/ and optional .git)
REPO_PATH="${GITHUB_REPO#https://github.com/}"
REPO_PATH="${REPO_PATH%.git}"
PUBLIC_IP="$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo '')"
if [ -n "${PUBLIC_IP}" ] && [ -n "${GITHUB_TOKEN}" ] && [ -n "${REPO_PATH}" ]; then
  echo "Creating GitHub webhook for ${REPO_PATH} -> http://${PUBLIC_IP}:8080/github-webhook/"
  # Prepare JSON payload
  PAYLOAD=$(cat <<JSON
{
  "name": "web",
  "active": true,
  "events": ["push"],
  "config": {
    "url": "http://${PUBLIC_IP}:8080/github-webhook/",
    "content_type": "json"
  }
}
JSON
)
  # call GitHub API
  curl -s -X POST -H "Authorization: token ${GITHUB_TOKEN}" -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/${REPO_PATH}/hooks \
    -d "${PAYLOAD}" || echo "Webhook creation returned non-zero exit code"
else
  echo "Skipping webhook creation (missing PUBLIC_IP or GITHUB_TOKEN or REPO_PATH)"
fi

echo "=== userdata finished ==="
date
