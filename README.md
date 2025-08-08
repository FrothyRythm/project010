
# NovaProject - Automated Deployment Pipeline (Beginner Friendly)

This project is called **NovaProject**. It is a beginner-friendly DevOps setup that helps you **automatically build, test, and deploy** a web application using **GitHub, Docker, Jenkins, Terraform, and AWS EC2**.

The goal is to make deployment **automatic and easy**, so you don’t need to do manual work every time you change your code.

---

##  What This Project Does
- Stores code in **GitHub** (version control).
- Packages the application in **Docker** (runs the same everywhere).
- Uses **Jenkins** to build and deploy automatically.
- Uses **Terraform** to create AWS EC2 servers automatically.
- Deploys your app to **AWS EC2**.

---

## 📂 Project Structure
```
NovaProject/
│
├── app/                   # Application source code
├── node_modules/          # Node.js dependencies
├── Dockerfile              # Instructions to build the Docker image
├── index.js                # Main application file
├── package.json            # Project dependencies
├── package-lock.json       # Locked versions of dependencies
├── .gitignore              # Files to ignore in Git
├── README.md               # Project documentation
├── destroy.bat             # Script to destroy AWS resources (Windows)
├── main.tf                 # Terraform file to create AWS EC2
├── terraform.tfvars        # Terraform variables file
└── variables.tf            # Terraform variables definition
│── Jenkinsfile           # Jenkins pipeline configuration
```

---

##  Step-by-Step Setup

### 1️⃣ Install Required Tools
Make sure you have installed:
- [Git](https://git-scm.com/)
- [Node.js](https://nodejs.org/)
- [Docker](https://www.docker.com/)
- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [Jenkins](https://www.jenkins.io/)
- AWS account

---

### 2️⃣ Clone This Repository
```bash
git clone https://github.com/your-username/NovaProject.git
cd NovaProject
```

---

### 3️⃣ Run the App Locally
```bash
npm install
node index.js
```
Check: Open your browser and go to `http://localhost:3000`.

---

### 4️⃣ Build Docker Image
```bash
docker build -t novaproject .
docker run -p 3000:3000 novaproject
```

---

### 5️⃣ Create AWS EC2 with Terraform
```bash
terraform init
terraform apply -auto-approve
```

---

### 6️⃣ Setup Jenkins Credentials
1. Open Jenkins Dashboard → Manage Jenkins → Credentials → (Global)
2. Add:
   - **GitHub Token** (Kind: Secret text)
   - **DockerHub Username/Password**
   - **AWS Access & Secret Keys**

---

### 7️⃣ Create Jenkins Pipeline
1. In Jenkins, create a **Pipeline Job**.
2. Connect to your GitHub repository.
3. Use `Jenkinsfile` to define pipeline stages.

---

### 8️⃣ Deploy to AWS EC2
Jenkins will automatically deploy the Docker container to your AWS EC2 instance.

---

## 🗑 Destroy Resources
When done, destroy EC2 to avoid costs:
```bash
terraform destroy -auto-approve
```

---

## Author
**Kshitij**  – AWS EC2 & Terraform setup, Docker, Jenkins CI/CD 

---
