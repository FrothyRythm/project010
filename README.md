# NovaProject – Automated Deployment Pipeline
NovaProject is a beginner-friendly DevOps project that automates the process of building, testing, and deploying a web application using GitHub, Docker, Jenkins, Terraform, and AWS EC2.

The aim is to make deployment fully automated so that whenever code is updated in GitHub, it gets deployed to AWS without manual work.

**🚀 What the Project Does**

Version Control – Stores and manages application code in GitHub.

Containerization – Packages the app into a Docker image so it runs identically everywhere.

CI/CD Automation – Uses Jenkins to build, test, and deploy automatically.

Infrastructure as Code (IaC) – Uses Terraform to create and configure AWS EC2 instances.

Automated Deployment – Deploys Docker containers to EC2.

Notifications – Sends email updates after successful pipeline execution.

**📂 Project Structure**

<img width="547" height="406" alt="image" src="https://github.com/user-attachments/assets/1942beac-1fff-4552-a26f-b81a14a34634" />




**🛠 Step-by-Step Implementation**

**1️⃣ Instance Creation with Terraform**
We used Terraform to provision an AWS EC2 instance. This happens right after pushing code changes to GitHub.

<img width="859" height="354" alt="image" src="https://github.com/user-attachments/assets/a1e1974c-190c-4a16-b3e0-a97d12be7f08" />


**2️⃣ Jenkins Setup & Configuration**
When the EC2 instance boots, it runs jenkins-userdata.sh which:

Installs Jenkins

Installs required plugins

Creates an admin user

Runs init-job.groovy to create a pipeline job automatically

Code Snippet (jenkins-userdata.sh):
#!/bin/bash
sudo apt update -y
sudo apt install -y openjdk-11-jdk
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt update -y
sudo apt install -y jenkins

**3️⃣ Jenkins Pipeline Execution**

The Jenkinsfile defines the following stages:

Pull latest code from GitHub

Build Docker image

Push image to DockerHub

Deploy container on EC2

Send email notification

Code Snippet (Jenkinsfile extract):
pipeline {
    agent any
    stages {
        stage('Build Docker Image') {
            steps {
                sh 'docker build -t my-docker-image .'
            }
        }
        stage('Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                    sh 'docker login -u $USER -p $PASS'
                    sh 'docker push my-docker-image'
                }
            }
        }
    }
}

<img width="1192" height="967" alt="image" src="https://github.com/user-attachments/assets/3f436445-922a-47bd-b21d-0dcafe50e75d" /> <img width="342" height="347" alt="image" src="https://github.com/user-attachments/assets/e1e83737-45ea-441b-91e3-b42b9e39cad1" />


**4️⃣ Email Notifications**
After the pipeline runs successfully, Jenkins sends an email notification to the team.

<img width="777" height="239" alt="image" src="https://github.com/user-attachments/assets/c5d42240-c623-4224-850c-8e82ba4fa0ee" />

**5️⃣ Application Deployment to EC2**
Once the pipeline finishes, the application is live and running in a Docker container on AWS EC2.


**📊 Data Flow Diagram**

<img width="892" height="555" alt="image" src="https://github.com/user-attachments/assets/b75dd05d-ed9c-411e-983d-7e29c1e966d7" />


🗑 Destroying Resources
To avoid AWS charges, destroy all created resources using:
terraform destroy -auto-approve


**👨‍💻 Contributors**

Kshitij – Terraform setup, AWS EC2 configuration, Jenkins automation

Vishal – Jenkins pipeline implementation

Shreya – Docker setup, documentation & README organization

Teesha – Application development, GitHub management
