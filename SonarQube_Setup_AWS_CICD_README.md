
# 🧠 SonarQube Setup on AWS with CI/CD Pipeline Integration

SonarQube is a static code analysis tool that continuously inspects code quality, detects bugs, highlights security vulnerabilities, and tracks technical debt. This guide walks you through the complete setup of SonarQube on an EC2 instance and its integration with AWS CodePipeline.

---

## 📋 Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Launch EC2 Instance](#launch-ec2-instance)
4. [Install SonarQube](#install-sonarqube)
5. [Configure Security Group](#configure-security-group)
6. [Access SonarQube UI](#access-sonarqube-ui)
7. [Integrate with AWS CodePipeline](#integrate-with-aws-codepipeline)
8. [Quality Gate Logic](#quality-gate-logic)
9. [What is a Quality Profile?](#what-is-a-quality-profile)

---

## 🔰 Introduction

SonarQube supports over 27 programming languages, including Java, Python, C#, Go, etc., and is widely used for:

- **Code Reliability**
- **Application Security**
- **Technical Debt Management**

---

## ✅ Prerequisites

- ✅ AWS EC2 instance (Amazon Linux 2) – `t2.small` or higher (2 GB RAM minimum)
- ✅ Java 11 installed:
```bash
sudo amazon-linux-extras install java-openjdk11
```
- ✅ Non-root user for running SonarQube

---

## 🚀 Launch EC2 Instance

1. Go to **EC2 → Launch Instance**
2. Choose **Amazon Linux 2 AMI (HVM)**
3. Instance Type: `t2.small` or larger
4. Configure Key Pair and Security Group

---

## 🛠 Install SonarQube

### 🔽 Step 1: Download and Unzip

```bash
cd /opt
wget https://binaries.sonarsource.com/CommercialDistribution/sonarqube-developer/sonarqube-developer-8.9.10.61524.zip
unzip sonarqube-developer-8.9.10.61524.zip
```

### 👤 Step 2: Create Sonar User

```bash
sudo useradd sonar
sudo chown -R sonar:sonar /opt/sonarqube
```

### ▶️ Step 3: Start SonarQube

```bash
sudo su - sonar
cd /opt/sonarqube/bin/linux-x86-64
./sonar.sh start
```

---

## 🔐 Configure Security Group

Add an **inbound rule** to allow traffic on **port 9000**.

![Security Group Settings](path/to/image)

---

## 🌐 Access SonarQube UI

- Use: `http://<EC2-Public-IP>:9000`
- Default Credentials:
  - **Username**: `admin`
  - **Password**: `admin`

> After first login, change the default password.

---

## 🔄 Integrate with AWS CodePipeline

### 📁 Step 1: Create a Project on SonarQube UI

- Click **Create Project Manually**
- Provide a **Project Display Name** and **Project Key**

![Create Project](path/to/image)

---

### 🔐 Step 2: Generate Token

Choose **Other CI** and create a **token**.

![Token Generation](path/to/image)

---

### ⚙️ Step 3: Copy Scanner Command

Example:
```bash
sonar-scanner \
  -Dsonar.projectKey=Test_Project \
  -Dsonar.sources=. \
  -Dsonar.host.url=http://<EC2-Public-IP>:9000 \
  -Dsonar.login=<TOKEN>
```

---

### 📦 Step 4: Update AWS CodePipeline

- Add a new stage: **Code-Review**
- Add a CodeBuild action and create a new CodeBuild project

![CodePipeline Stage](path/to/image)

---

### ⚙️ CodeBuild Configuration

- **OS**: Ubuntu
- **Image**: aws/codebuild/standard:5.0
- **Privileged Mode**: Enabled
- Use `buildspec.yml` with the `sonar-scanner` command

![CodeBuild Settings](path/to/image)

---

## ✅ Sample `buildspec.yml`

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      java: corretto11
  build:
    commands:
      - sonar-scanner \
        -Dsonar.projectKey=Test_Project \
        -Dsonar.sources=. \
        -Dsonar.host.url=http://<EC2-IP>:9000 \
        -Dsonar.login=<TOKEN>
```

---

## 🚦 Quality Gate Logic

SonarQube Quality Gates determine whether code meets specific standards. Possible outcomes:

- `OK`: Code meets all criteria
- `ERROR`: Code fails gate conditions
- `WARN`: Minor issues
- `None`: No gate assigned

> Use the result in CodeBuild via environment variable:

```bash
export CODEBUILD_BUILD_SUCCEEDING=0  # Fail the build if gate fails
```

---

## 🧾 What is a Quality Profile?

A **Quality Profile** defines coding standards and rules. It helps:

- Maintain readability, performance, and security
- Reduce technical debt
- Ensure compliance with team/project standards

> Profiles can be customized per language, team, or project.

---

## 📊 Final SonarQube Dashboard

After pipeline execution, your SonarQube dashboard should reflect test results and analysis:

![SonarQube Dashboard](path/to/image)

---

## 🏁 Summary

✅ SonarQube improves code quality  
✅ Integrated with AWS CodePipeline using CodeBuild  
✅ Setup runs on EC2 with Java 11  
✅ Visual reports in dashboard + pipeline fail if code quality fails  
