#!/bin/bash
set -e

# Update system and install Java
sudo apt-get update -y
sudo apt-get install -y openjdk-17-jdk curl git

# Add Jenkins repo and install Jenkins
curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y jenkins

# Start Jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Wait for Jenkins to start
echo "Waiting for Jenkins to fully start..."
sleep 60

# Install Jenkins CLI
JENKINS_CLI=/tmp/jenkins-cli.jar
wget -q http://localhost:8080/jnlpJars/jenkins-cli.jar -O $JENKINS_CLI

# Install required plugins
PLUGINS=(
  configuration-as-code
  git
  email-ext
  job-dsl
  pipeline
  workflow-aggregator
)
for plugin in "${PLUGINS[@]}"; do
    java -jar $JENKINS_CLI -s http://localhost:8080/ install-plugin $plugin -deploy
done

# Create JCasC config file
sudo mkdir -p /var/lib/jenkins/init.groovy.d
sudo tee /var/lib/jenkins/casc.yaml > /dev/null <<'EOL'
jenkins:
  systemMessage: "Automated Jenkins Setup for Node.js CI/CD"
  numExecutors: 2
  mode: NORMAL
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: "admin"
          password: "admin123"
          email: "kshitijsinha1002@gmail.com"
  authorizationStrategy:
    loggedInUsersCanDoAnything:
      allowAnonymousRead: false
  remotingSecurity:
    enabled: true

unclassified:
  location:
    url: "http://localhost:8080/"
    adminAddress: "kshitijsinha1002@gmail.com"

  mailer:
    smtpHost: "smtp.gmail.com"
    smtpPort: 587
    useSsl: false
    charset: "UTF-8"
    useTls: true
    smtpAuthUsername: "kshitijsinha1002@gmail.com"
    smtpAuthPassword: "hjsh udio qaih zbdr"

jobs:
  - script: >
      pipelineJob('NodeJS-CICD') {
        definition {
          cpsScm {
            scm {
              git {
                remote { url('https://github.com/FrothyRythm/project010.git') }
                branches('*/main')
              }
            }
            scriptPath('Jenkinsfile')
          }
        }
        triggers {
          scm('* * * * *')
        }
      }
EOL

# Create Groovy script for initial job
sudo tee /var/lib/jenkins/init.groovy.d/init-job.groovy > /dev/null <<'EOL'
import jenkins.model.*
import hudson.plugins.git.*
import javaposse.jobdsl.plugin.*

def jenkins = Jenkins.instance

def jobName = "NodeJS-CICD"
def job = jenkins.getItem(jobName)

if (job == null) {
    println "Creating job: ${jobName}"
    def jobDsl = """
        pipelineJob('${jobName}') {
            definition {
                cpsScm {
                    scm {
                        git {
                            remote { url('https://github.com/FrothyRythm/project010.git') }
                            branches('*/main')
                        }
                    }
                    scriptPath('Jenkinsfile')
                }
            }
            triggers {
                scm('* * * * *')
            }
        }
    """
    def jobDslScript = new ExecuteDslScripts(
        scriptText: jobDsl,
        usingScriptText: true
    )
    jobDslScript.run()
} else {
    println "Job '${jobName}' already exists"
}
EOL

# Enable JCasC
echo 'CASC_JENKINS_CONFIG=/var/lib/jenkins/casc.yaml' | sudo tee -a /etc/default/jenkins

# Restart Jenkins to apply config
sudo systemctl restart jenkins
