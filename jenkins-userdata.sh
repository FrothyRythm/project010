#!/bin/bash
apt-get update
apt-get install -y openjdk-17-jdk wget git

# Install Jenkins
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io-2023.key | tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian binary/ | tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update
apt-get install -y jenkins

# Install plugins via JCasC
mkdir -p /var/jenkins_home/casc_configs
cp /tmp/casc.yaml /var/jenkins_home/casc_configs/casc.yaml
cp /tmp/init-job.groovy /var/jenkins_home/init.groovy.d/init-job.groovy
chown -R jenkins:jenkins /var/jenkins_home

# Enable JCasC in Jenkins startup
echo 'JAVA_ARGS="-Djenkins.install.runSetupWizard=false -Djenkins.config.runSetupWizard=false -Djenkins.config.Casc.config=/var/jenkins_home/casc_configs/casc.yaml"' >> /etc/default/jenkins

systemctl enable jenkins
systemctl restart jenkins
