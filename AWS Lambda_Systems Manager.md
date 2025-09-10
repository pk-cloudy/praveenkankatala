# Automated EC2 Management via AWS Lambda & Systems Manager (SSM)

A production‑ready, least‑privilege, API‑driven solution to **run shell commands on EC2 instances** and **trigger SSM State Manager associations** using AWS Lambda and API Gateway (HTTP API v2). Comes with Terraform IaC, robust Lambda handlers, and clear security boundaries.

---

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Use Cases](#use-cases)
- [Components](#components)
- [Security Model](#security-model)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Deploy with Terraform](#deploy-with-terraform)
- [Configuration & Variables](#configuration--variables)
- [How It Works (Flows)](#how-it-works-flows)
- [API Reference](#api-reference)
- [EC2 Instance Preparation](#ec2-instance-preparation)
- [Running & Testing](#running--testing)
- [Observability](#observability)
- [Troubleshooting](#troubleshooting)
- [Cost Considerations](#cost-considerations)
- [Extending the Solution](#extending-the-solution)
- [FAQ](#faq)
- [Appendix: Terraform Files Explained](#appendix-terraform-files-explained)

---

## Overview

This project exposes two secure endpoints via **API Gateway (HTTP API v2)** to control EC2 maintenance through **AWS Systems Manager (SSM)**:

1. **Run Commands on EC2** — Send a vetted set of shell commands (or caller‑provided commands) to a single EC2 instance using the SSM document `AWS-RunShellScript`. The Lambda function polls for results and returns stdout/stderr and status. Large outputs can optionally be saved to S3.
2. **Start SSM Association Once** — Trigger an existing **SSM State Manager Association** one‑time by its `AssociationId` (useful for patching, hardening, or routine workflows).

By design, the APIs are **private by default** (IAM‑only). You can later attach Cognito/JWT or a Lambda authorizer if external callers need access.

---

## Architecture

```
[Client (SDK/Postman w/ SigV4)]
            |
            v
   API Gateway (HTTP API v2)
      (IAM Authorization)
            |
            v
         AWS Lambda
   ├─ run-commands (Python 3.12)
   └─ start-association (Python 3.12)
            |
            v
   AWS Systems Manager (SSM)
   ├─ SendCommand (AWS-RunShellScript)
   └─ StartAssociationsOnce
            |
            v
         EC2 Instance(s)
        (SSM Agent online)
            |
           S3 (optional output)
            |
         CloudWatch Logs
```

**Key controls:**  
- **Instance tag gate** (`SSMRunAllowed=true`) ensures only *explicitly approved* instances receive commands.  
- **Least‑privilege IAM** for Lambda allows only the SSM actions required and only for resources you control.  
- **IAM‑only API routes** mean calls must be **SigV4-signed** with an AWS principal you approve.

---

## Use Cases

- On‑demand server diagnostics (kernel, CPU, memory, disk, running services).
- Targeted remediation tasks (restart a service, rotate logs, clear temp, etc.).
- One‑off execution of a hardened **SSM Association** (e.g., patch baseline run).
- Building a thin “Ops API” for controlled automation from ITSM/ChatOps tools.

> ⚠️ **Safety**: Only allow specific users/roles to invoke the APIs. Consider allow‑listing commands in production environments.

---

## Components

- **Lambda (Python 3.12)**
  - `run_commands`: Sends SSM `SendCommand` and polls results with backoff.
  - `start_association`: Calls `StartAssociationsOnce` by `AssociationId`.
- **API Gateway (HTTP API v2)**: Two routes `POST /run-commands` and `POST /start-association` with **AWS_IAM authorization**.
- **IAM**
  - Lambda execution role with *least privilege* to SSM + CloudWatch Logs (+optional S3 put).
  - EC2 instance role: **`AmazonSSMManagedInstanceCore`**.
- **Optional S3** for large command outputs.
- **CloudWatch Logs** for API access logs and Lambda function logs.

---

## Security Model

1. **API Authorization**: Routes use **`AWS_IAM`**. Callers must SigV4‑sign requests with an IAM principal you control (works with Postman or any AWS SDK).
2. **Resource Scoping**:
   - `ssm:SendCommand` limited to the `AWS-RunShellScript` document and to **instances tagged** `SSMRunAllowed=true` using the `ssm:resourceTag/...` condition.
   - `ssm:GetCommandInvocation` read‑only for results.
   - `ssm:StartAssociationsOnce` scoped to your account region.
3. **Instance Gate**: Only instances with `SSMRunAllowed=true` are eligible targets.
4. **Logging**: All Lambda executions and API access are logged to **CloudWatch Logs**.
5. **Data at Rest**: Optional S3 output for large logs; consider enabling bucket encryption & tight bucket policies.

---

## Prerequisites

- **AWS Account** with permissions to create IAM, Lambda, API Gateway, S3, and CloudWatch Logs.
- **Terraform** `>= 1.6.0` and **AWS Provider** `>= 5.60`.
- **AWS CLI** configured (or environment creds) to run `terraform apply`.
- **EC2 Instances** you plan to manage must have:
  - **SSM Agent** installed and **online**.
  - Instance profile **`AmazonSSMManagedInstanceCore`** attached.
  - Network access to SSM endpoints (public internet or **VPC interface endpoints** for `ssm`, `ssmmessages`, `ec2messages`; S3 endpoint if using S3 output).
  - Tag **`SSMRunAllowed=true`**.

---

## Project Structure

```
ec2-ssm-automation/
├─ infra/
│  ├─ backend.tf
│  ├─ provider.tf
│  ├─ variables.tf
│  ├─ locals.tf
│  ├─ iam.tf
│  ├─ lambda.tf
│  ├─ apigw.tf
│  ├─ outputs.tf
├─ lambdas/
│  ├─ run_commands/
│  │  └─ handler.py
│  └─ start_association/
│     └─ handler.py
└─ README.md  (this file)
```

---

## Deploy with Terraform

1. **Package Lambdas**
   ```bash
   zip -r lambdas/run_commands.zip lambdas/run_commands
   zip -r lambdas/start_association.zip lambdas/start_association
   ```

2. **Initialize & Apply**
   ```bash
   cd infra
   terraform init
   terraform apply \
     -var="aws_region=ap-south-1" \
     -var="project=ec2-ssm" \
     -var="environment=dev" \
     -var="output_s3_bucket="   # set to an S3 bucket name to enable S3 outputs
   ```

3. **Outputs**
   - `api_endpoint` — base URL for API Gateway (e.g., `https://abc123.execute-api.ap-south-1.amazonaws.com`)
   - `ec2_instance_profile_name` — attach this to instances you manage.
   - Lambda function names for reference.

> **Note**: API Gateway stage is `$default` and auto‑deploy is enabled.

---

## Configuration & Variables

| Variable | Description | Example |
|---|---|---|
| `aws_region` | AWS region to deploy | `ap-south-1` |
| `aws_profile` | Optional AWS named profile | `default` |
| `project` | Project name prefix | `ec2-ssm` |
| `environment` | Environment string | `dev` |
| `output_s3_bucket` | (Optional) S3 bucket to store SSM command outputs | `my-ops-logs` |

**Lambda Environment Variables** (set in Terraform):
- `SSM_DOCUMENT` — defaults to `AWS-RunShellScript` (use `AWS-RunPowerShellScript` for Windows).
- `OUTPUT_S3_BUCKET` / `OUTPUT_S3_PREFIX` — if set, full outputs are written to S3 and a preview is returned.
- `REQUIRE_TAG_KEY` / `REQUIRE_TAG_VALUE` — defaults to `SSMRunAllowed=true`.

**Function Sizing**:
- `run_commands`: 120s timeout, 512MB memory (tune as needed).
- `start_association`: 30s timeout, 256MB memory.

---

## How It Works (Flows)

### 1) Run Commands Flow
1. Client `POST /run-commands` with JSON: `{ "instance_id": "i-...", "commands": ["uptime"] }`.
2. API Gateway authorizes with **IAM** and invokes Lambda.
3. Lambda validates instance + tag, calls `ssm:SendCommand` with the `AWS-RunShellScript` document.
4. Lambda polls `GetCommandInvocation` with exponential backoff.
5. Returns JSON with `status`, `stdout` (truncated if large), and optional S3 location.

### 2) Start Association Flow
1. Client `POST /start-association` with JSON: `{ "association_id": "..." }`.
2. Lambda calls `StartAssociationsOnce`.
3. Returns `started: true` and the raw API response for auditing.

---

## API Reference

### Auth
- **Authorization type**: `AWS_IAM` (SigV4).  
- In **Postman**: Auth → *AWS Signature*, set Access Key, Secret, Service = `execute-api`, Region = your region.

### `POST /run-commands`
**Body**
```json
{
  "instance_id": "i-0123456789abcdef0",
  "commands": ["hostname", "uptime"]   // optional; defaults are provided
}
```
**Response (Success)**
```json
{
  "status": "Success",
  "status_details": "Success",
  "stdout": "System Information: ...",
  "stderr": "",
  "bucket": "my-ops-logs",
  "key_prefix": "ssm/outputs",
  "command_id": "abc123-..."
}
```
**Possible 4xx/5xx**
- `400` missing fields or invalid types.
- `403` instance missing required tag or not allowed.
- `504` command timed out before completion.
- `500` SSM/Client error message.

### `POST /start-association`
**Body**
```json
{ "association_id": "e8b9f3a7-EXAMPLE" }
```
**Response (Success)**
```json
{ "started": true, "association_id": "e8b9f3a7-EXAMPLE", "response": { "...": "..." } }
```

---

## EC2 Instance Preparation

1. **Attach Instance Profile**
   - Use the Terraform‑created instance profile output or attach **`AmazonSSMManagedInstanceCore`** to your existing role.
2. **Install/Verify SSM Agent** (Amazon Linux 2 & many AMIs include it).
3. **Tag the Instance**
   - Add: `SSMRunAllowed=true` (customizable via env vars/policy condition).
4. **Network Connectivity**
   - Internet egress **or** VPC Interface Endpoints:
     - `com.amazonaws.<region>.ssm`
     - `com.amazonaws.<region>.ssmmessages`
     - `com.amazonaws.<region>.ec2messages`
     - (Optional for S3 outputs) `com.amazonaws.<region>.s3`

---

## Running & Testing

### With Postman
1. Set **Auth → AWS Signature** (Access Key/Secret with `execute-api:Invoke`).
2. Method: `POST`, URL: `<api_endpoint>/run-commands`.
3. Body (raw JSON): `{"instance_id": "i-...", "commands": ["uptime"]}`.
4. Send and inspect JSON response.

### With `curl` + SigV4
- Use a helper like [`awscurl`](https://github.com/okigan/awscurl) or sign requests with your SDK.  
- Alternatively, invoke Lambda directly (skips API Gateway):  
  `aws lambda invoke --function-name <name> --payload '{"instance_id":"i-..."}' out.json`

---

## Observability

- **CloudWatch Logs**:
  - `/aws/lambda/<function>` — application logs & errors.
  - `/aws/apigw/<api-name>` — API access logs ($default stage).
- **Useful Log Insights Query** (Lambda errors):
  ```
  fields @timestamp, @message
  | filter @logStream like /run-commands/
  | filter ispresent(@message) and @message like /error|Exception|AccessDenied|TimedOut|Failed/i
  | sort @timestamp desc
  | limit 50
  ```
- Consider enabling **X-Ray** on Lambda for tracing across SSM calls.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| `403` from API | Missing SigV4 / wrong creds / principal lacks `execute-api:Invoke` | Use IAM auth in Postman; attach an IAM policy granting `execute-api:Invoke` on this API/stage |
| Lambda returns `403` (permission error) | Instance missing required tag | Tag instance `SSMRunAllowed=true` or adjust `REQUIRE_TAG_*` |
| `InvocationDoesNotExist` errors transiently | SSM propagation delay | Lambda backs off; usually resolves in a few seconds |
| `Status = Failed` with stderr | Command invalid for OS / missing package | Adjust command set; test command via console SSM Run Command |
| `Timed out waiting for command result` | Long‑running command | Increase Lambda timeout; or write full output to S3 and return early |
| No SSM connection | Agent not installed / VPC endpoints missing | Install agent; add interface endpoints (`ssm`, `ssmmessages`, `ec2messages`) |
| StartAssociationsOnce error | Invalid `AssociationId` or permissions | Validate ID in SSM console; ensure policy allows `ssm:StartAssociationsOnce` |

---

## Cost Considerations

- **Lambda**: Pay per ms execution; keep timeouts reasonable.
- **API Gateway (HTTP API)**: Cheaper than REST API; pay per request.
- **SSM**: Most features used here are no‑additional‑charge; advanced features (Session Manager port forwarding / OpsCenter) may incur costs.
- **CloudWatch Logs**: Ingestion + storage (set sensible retention).
- **S3**: Optional storage for outputs (requests + storage).

---

## Extending the Solution

- **Cognito/JWT Authorizer** for end‑user auth instead of IAM.
- **Command Allow‑List** and server‑side validation.
- **Windows Support**: set `SSM_DOCUMENT=AWS-RunPowerShellScript` and adapt default commands.
- **Fan‑out to many instances**: accept tags or filters, send to `Targets` (SSM) and aggregate results via **Step Functions**.
- **EventBridge Schedules** for routine checks (CPU/disk snapshot).
- **Alarming**: CloudWatch Alarms on Lambda errors or SSM `Failed` statuses.
- **S3 Encryption & SSE‑KMS**, tighter bucket policies, VPC‑only endpoints.

---

## FAQ

**Q: Why not use `AmazonEC2RoleforSSM` on instances?**  
A: It’s legacy. Use **`AmazonSSMManagedInstanceCore`**, which includes all modern SSM permissions and messaging channels.

**Q: Can I restrict which commands are allowed?**  
A: Yes—remove the `commands` field from the request schema and hardcode/allow‑list on the server, or validate against a regex/enum.

**Q: Can I target multiple instances at once?**  
A: This blueprint targets one `instance_id`. For multi‑target, use SSM `Targets` (by tag) and aggregate in Step Functions for reliability.

**Q: How do I support Windows?**  
A: Switch the document to `AWS-RunPowerShellScript` and supply PowerShell commands.

**Q: Do I need internet access from instances?**  
A: Not if you provision **VPC interface endpoints** for SSM/SSMMessages/EC2Messages and (optionally) S3 for outputs.

---

## Appendix: Terraform Files Explained

- **`provider.tf`** — Pins Terraform and providers; sets the AWS region/profile.
- **`variables.tf`** — Declares configurable inputs (region, project, environment, optional S3 bucket).
- **`locals.tf`** — Standardizes naming and tags across resources.
- **`iam.tf`** —
  - Lambda execution role with **least‑privilege** SSM + logs (+optional S3 write).
  - **Condition** on `ssm:SendCommand` to require tag `SSMRunAllowed=true` on target instances.
  - EC2 instance role/profile with **`AmazonSSMManagedInstanceCore`**.
- **`lambda.tf`** — Packages & configures both Lambda functions, timeouts, memory, and environment variables.
- **`apigw.tf`** — Creates the HTTP API, `$default` stage, access logs, routes, Lambda integrations, and invoke permissions.
- **`outputs.tf`** — Prints the API endpoint and key resource names for convenience.

---

**👍 You’re ready to run controlled, auditable maintenance against EC2—securely and repeatably.**

