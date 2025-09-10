
# SonarQube Setup, .NET Scanning on Windows, and AWS CodeBuild Integration

This README consolidates clean, production‑ready steps to **deploy SonarQube on Amazon Linux EC2**, **scan .NET projects from Windows**, and **run SonarQube analysis from AWS CodeBuild** using an Ubuntu-based managed image.

---

## Table of Contents
- [Architecture at a Glance](#architecture-at-a-glance)
- [Part A — SonarQube on Amazon Linux EC2](#part-a--sonarqube-on-amazon-linux-ec2)
  - [A.1 Prerequisites](#a1-prerequisites)
  - [A.2 Install Java and tools](#a2-install-java-and-tools)
  - [A.3 Create Sonar user, download & unpack SonarQube](#a3-create-sonar-user-download--unpack-sonarqube)
  - [A.4 Kernel & ulimit requirements](#a4-kernel--ulimit-requirements)
  - [A.5 Optional: SonarQube bind & database config](#a5-optional-sonarqube-bind--database-config)
  - [A.6 Systemd service](#a6-systemd-service)
  - [A.7 Start, verify, and access the UI](#a7-start-verify-and-access-the-ui)
  - [A.8 Troubleshooting EC2 install](#a8-troubleshooting-ec2-install)
- [Part B — Scanning .NET on Windows with SonarScanner for .NET](#part-b--scanning-net-on-windows-with-sonarscanner-for-net)
  - [B.1 Prerequisites](#b1-prerequisites)
  - [B.2 Install SonarScanner for .NET (global tool)](#b2-install-sonarscanner-for-net-global-tool)
  - [B.3 Optional but recommended: tests & coverage](#b3-optional-but-recommended-tests--coverage)
  - [B.4 Run the scan (SDK-style .NET projects)](#b4-run-the-scan-sdk-style-net-projects)
  - [B.5 .NET Framework (MSBuild) variant](#b5-net-framework-msbuild-variant)
  - [B.6 Optional: Generic CLI scanner](#b6-optional-generic-cli-scanner)
  - [B.7 Troubleshooting Windows scan](#b7-troubleshooting-windows-scan)
- [Part C — AWS CodeBuild with SonarQube](#part-c--aws-codebuild-with-sonarqube)
  - [C.1 Create the CodeBuild project](#c1-create-the-codebuild-project)
  - [C.2 IAM for Secrets Manager](#c2-iam-for-secrets-manager)
  - [C.3 `buildspec.yml` (Ubuntu image)](#c3-buildspecyml-ubuntu-image)
  - [C.4 Optional: Generic SonarScanner CLI in CodeBuild](#c4-optional-generic-sonarscanner-cli-in-codebuild)
  - [C.5 Networking checklist](#c5-networking-checklist)
  - [C.6 Common pitfalls in CodeBuild](#c6-common-pitfalls-in-codebuild)
- [Appendix — Notes on Version Compatibility](#appendix--notes-on-version-compatibility)

---

## Architecture at a Glance

- **SonarQube Server**: Hosted on **Amazon Linux EC2** (t2.small or larger). Exposes HTTP on port **9000**.
- **Developers / CI**: 
  - **Windows** dev boxes run **dotnet-sonarscanner** against the server.
  - **AWS CodeBuild** uses **`aws/codebuild/standard:5.0` (Ubuntu)** runtime to build & scan .NET code and publish to the same SonarQube server.
- **Auth**: SonarQube token stored securely (local environment variable on Windows; **AWS Secrets Manager** in CI).

---

## Part A — SonarQube on Amazon Linux EC2

### A.1 Prerequisites

- EC2 instance: **t2.small (2GB RAM)** minimum (bigger is better for multi‑user).
- Security Group: open **TCP 9000** inbound from your trusted IP/VPC.
- SonarQube **must not** run as root: create a dedicated system user.
- **Java 11** for SonarQube **8.9.x** (LTS in your example). Newer SonarQube versions require **Java 17** (see Appendix).

### A.2 Install Java and tools

```bash
# As ec2-user (use sudo as needed)
sudo yum install -y unzip curl tar

# Amazon Linux 2:
sudo amazon-linux-extras install java-openjdk11 -y
# (If using Amazon Linux 2023 instead):
# sudo dnf install -y java-11-amazon-corretto
```

### A.3 Create Sonar user, download & unpack SonarQube

```bash
# Create a 'sonar' system user (login shell enabled for convenience)
sudo useradd --system --home /opt/sonarqube --shell /bin/bash sonar

cd /opt
# Example: Developer Edition 8.9.10 (from your reference)
sudo curl -LO https://binaries.sonarsource.com/CommercialDistribution/sonarqube-developer/sonarqube-developer-8.9.10.61524.zip

sudo unzip sonarqube-developer-8.9.10.61524.zip
sudo ln -s sonarqube-developer-8.9.10.61524 sonarqube

# Ensure ownership
sudo chown -R sonar:sonar /opt/sonarqube /opt/sonarqube-developer-8.9.10.61524
```

> **Paths note:** If you previously used `/home/pk/sonarqube`, adjust the service commands accordingly. This guide standardizes on `/opt/sonarqube`.

### A.4 Kernel & ulimit requirements

```bash
# Required for Elasticsearch
echo 'vm.max_map_count=524288' | sudo tee /etc/sysctl.d/99-sonarqube.conf
echo 'fs.file-max=131072'      | sudo tee -a /etc/sysctl.d/99-sonarqube.conf
sudo sysctl --system

# Per-user limits
sudo tee /etc/security/limits.d/99-sonarqube.conf >/dev/null <<'EOF'
sonar   -   nofile  65536
sonar   -   nproc   4096
EOF
```

### A.5 Optional: SonarQube bind & database config

```bash
# Bind to all interfaces (or specify IP)
sudo -u sonar sed -i 's|#sonar.web.host=|sonar.web.host=0.0.0.0|' /opt/sonarqube/conf/sonar.properties
sudo -u sonar sed -i 's|#sonar.web.port=9000|sonar.web.port=9000|' /opt/sonarqube/conf/sonar.properties

# Use embedded H2 only for evaluation. For production, configure PostgreSQL, e.g.:
# sudo -u sonar bash -lc "cat >> /opt/sonarqube/conf/sonar.properties <<'EOP'
# sonar.jdbc.url=jdbc:postgresql://<DB_HOST>:5432/sonarqube
# sonar.jdbc.username=sonar
# sonar.jdbc.password=<strong-password>
# EOP"
```

### A.6 Systemd service

```ini
# /etc/systemd/system/sonar.service
[Unit]
Description=SonarQube service
After=network.target

[Service]
Type=forking
User=sonar
Group=sonar
WorkingDirectory=/opt/sonarqube
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop

# Recommended limits
LimitNOFILE=65536
LimitNPROC=4096

# Robustness
Restart=always
RestartSec=5s
TimeoutStartSec=300
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable sonar
sudo systemctl start sonar
sudo systemctl status sonar --no-pager
```

### A.7 Start, verify, and access the UI

```bash
# Logs
sudo journalctl -u sonar -f
# Confirm port
ss -lntp | grep 9000
```

Access `http://<EC2-Public-IP>:9000` (open Security Group).  
Default credentials (8.9): `admin / admin` (will be prompted to change).

### A.8 Troubleshooting EC2 install

- **Java mismatch**: SonarQube 8.9.x needs Java 11. Check `java -version` (as `sonar`).
- **Limits not applied**: ensure `sysctl --system` succeeded; consider reboot.
- **Permission denied**: `chown -R sonar:sonar /opt/sonarqube*`.
- **Port blocked**: update Security Group to allow TCP/9000.
- **DB errors**: verify JDBC URL/creds and network to PostgreSQL.

---

## Part B — Scanning .NET on Windows with SonarScanner for .NET

### B.1 Prerequisites

- **SonarQube server** URL, e.g., `http://10.10.60.201:9000`.
- **SonarQube token** (avoid hardcoding in scripts).
- **.NET SDK** installed: `dotnet --version`.
- For **.NET Framework** builds: **Visual Studio Build Tools** (MSBuild).

### B.2 Install SonarScanner for .NET (global tool)

```powershell
# PowerShell
dotnet tool install --global dotnet-sonarscanner

# Ensure tools path on PATH for this session:
$env:PATH = "$env:PATH;$env:USERPROFILE\.dotnet\tools"

# Store token securely in process env (session-scoped):
$env:SONAR_TOKEN = "<your-token>"
```

### B.3 Optional but recommended: tests & coverage

**Coverlet (OpenCover):**
- Pass `/d:sonar.cs.opencover.reportsPaths="**/coverage.opencover.xml"` to `begin`.
- Run tests with coverage:
  ```powershell
  dotnet test -c Release --no-build `
    /p:CollectCoverage=true `
    /p:CoverletOutput=./coverage.opencover.xml `
    /p:CoverletOutputFormat=opencover `
    /l:trx
  ```

### B.4 Run the scan (SDK-style .NET projects)

```powershell
# In solution root
dotnet sonarscanner begin `
  /k:"test" `
  /d:sonar.host.url="http://10.10.60.201:9000" `
  /d:sonar.login="$env:SONAR_TOKEN" `
  /d:sonar.qualitygate.wait=true `
  /d:sonar.cs.opencover.reportsPaths="**/coverage.opencover.xml" `
  /d:sonar.cs.vstest.reportsPaths="**/*.trx"

dotnet restore
dotnet build --no-restore -c Release
dotnet test --no-build -c Release `
  /p:CollectCoverage=true `
  /p:CoverletOutput=./coverage.opencover.xml `
  /p:CoverletOutputFormat=opencover `
  /l:trx

dotnet sonarscanner end /d:sonar.login="$env:SONAR_TOKEN"
```

> You typically **don’t need** a `sonar-project.properties` file for the .NET Scanner. It’s configured via `begin`/`end`.

### B.5 .NET Framework (MSBuild) variant

```powershell
dotnet sonarscanner begin `
  /k:"test" `
  /d:sonar.host.url="http://10.10.60.201:9000" `
  /d:sonar.login="$env:SONAR_TOKEN"

# Adjust MSBuild path for your installation
"C:\Program Files\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe" .\YourSolution.sln /t:Rebuild /p:Configuration=Release

# (Optional) collect coverage with OpenCover/dotCover and pass report paths accordingly

dotnet sonarscanner end /d:sonar.login="$env:SONAR_TOKEN"
```

### B.6 Optional: Generic CLI scanner

Create `sonar-project.properties` if using the **generic** CLI (for non-.NET code):

```
sonar.projectKey=test
sonar.projectName=Test Project
sonar.projectVersion=1.0
sonar.sources=.
```

Then run (Java required):

```powershell
sonar-scanner -Dsonar.host.url="http://10.10.60.201:9000" -Dsonar.login="$env:SONAR_TOKEN"
```

### B.7 Troubleshooting Windows scan

- **401/403**: token missing/expired; or no permission to create projects.
- **Project not visible**: mismatch in project key or permissions.
- **“No files to analyze” / no coverage**: ensure you build/test **between** `begin` and `end`; verify report glob patterns.
- **Scanner not found**: add `%USERPROFILE%\.dotnet\tools` to PATH or re-open shell.
- **Connectivity**: firewall to port **9000** on the SonarQube server.

---

## Part C — AWS CodeBuild with SonarQube

### C.1 Create the CodeBuild project

- Console → **CodeBuild** → **Create build project**.
- Source provider: **GitHub** (or CodeCommit, etc.).
- Environment: **Ubuntu** managed image `aws/codebuild/standard:5.0`, runtime `dotnet: 8.0`.

### C.2 IAM for Secrets Manager

Store the Sonar token in **AWS Secrets Manager** (e.g., secret name `sonar/token` with key `sonarkey`).  
Attach this policy to CodeBuild service role (scope to your secret ARN):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:<REGION>:<ACCOUNT_ID>:secret:sonar/token*"
    }
  ]
}
```

### C.3 `buildspec.yml` (Ubuntu image)

```yaml
version: 0.2

env:
  variables:
    SONAR_HOST_URL: "http://52.66.214.69:9000"   # Replace with your SonarQube URL
  secrets-manager:
    SONAR_TOKEN: "sonar/token:sonarkey"          # Secrets Manager secret:key

phases:
  install:
    runtime-versions:
      dotnet: 8.0
    commands:
      - echo "Install phase ..."
      - dotnet --info
      - apt-get update -y
      - apt-get install -y unzip
      - dotnet tool install --global dotnet-sonarscanner
      - export PATH="$PATH:/root/.dotnet/tools"

  pre_build:
    commands:
      - echo "Pre build phase ..."
      - echo "Working dir: $(pwd)"

  build:
    commands:
      - echo "Build phase ..."
      - dotnet sonarscanner begin /k:"test-dotnet" /d:sonar.host.url="$SONAR_HOST_URL" /d:sonar.login="$SONAR_TOKEN" /d:sonar.cs.opencover.reportsPaths="**/coverage.opencover.xml"
      - dotnet restore
      - dotnet build --no-restore -c Release
      - dotnet test --no-build -c Release /p:CollectCoverage=true /p:CoverletOutput=./coverage.opencover.xml /p:CoverletOutputFormat=opencover
      - dotnet sonarscanner end /d:sonar.login="$SONAR_TOKEN"

  post_build:
    commands:
      - echo "Post build phase ..."
```

### C.4 Optional: Generic SonarScanner CLI in CodeBuild

For non-.NET repositories:

```yaml
phases:
  install:
    runtime-versions:
      java: corretto17
    commands:
      - apt-get update -y && apt-get install -y unzip wget
      - wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
      - unzip sonar-scanner-cli-5.0.1.3006-linux.zip
      - export PATH="$PATH:$(pwd)/sonar-scanner-5.0.1.3006-linux/bin"
  build:
    commands:
      - sonar-scanner -Dsonar.projectKey=test-cli -Dsonar.host.url="$SONAR_HOST_URL" -Dsonar.login="$SONAR_TOKEN"
```

### C.5 Networking checklist

- CodeBuild must reach `http://<sonarqube-host>:9000`.
  - If SonarQube is **publicly accessible**, allow your CodeBuild egress in the server SG/firewall.
  - If SonarQube is **private** (in VPC):
    - Attach the CodeBuild project to the **same VPC/subnets** and ensure routing (NAT for internet, if needed).
    - Open **Security Groups** appropriately (CodeBuild → SonarQube 9000/TCP).

### C.6 Common pitfalls in CodeBuild

- Using `yum`/`rpm` on the Ubuntu image → use `apt-get`.
- Running `sudo` in CodeBuild → you’re already root.
- PATH missing for dotnet tools → export `/root/.dotnet/tools`.
- Secrets Manager mapping must match `secret:key` in `buildspec.yml`.
- Analysis not published → network blocked or wrong `SONAR_HOST_URL`/token.

---

## Appendix — Notes on Version Compatibility

- **SonarQube 8.9.x (LTS)** — requires **Java 11** (your EC2 instructions align with this).
- **Newer SonarQube versions (9.9 LTS / 10.x)** — require **Java 17**. If you upgrade SonarQube, also update Java accordingly.
- SonarQube does **not** run as root. Always run it as a dedicated user (e.g., `sonar`).

---


