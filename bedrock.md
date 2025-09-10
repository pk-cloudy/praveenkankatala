You don’t “create Bedrock” with Terraform. Bedrock (the service) already exists in your AWS account.
With Terraform you turn on or set up **specific Bedrock features**. Think of it like this:

* **Bedrock = platform** (already there)
* **Terraform = switches and dials** you set for the parts you need

Here are the common goals and the exact Terraform blocks you use—explained in plain English.

---

## If you want to… call a foundation model (on-demand)

**No Terraform resource needed.**
You just give your app IAM permission and call Bedrock with SDK/CLI.
(Optional) Turn on account-wide logs below.

---

## If you want to… record all prompts/responses for auditing

**Use:** `aws_bedrock_model_invocation_logging_configuration`
**What it does:** Tells Bedrock to write invocation logs to CloudWatch Logs and/or S3.
**Why:** Troubleshooting, audits, analytics.

*Minimal snippet:*

```hcl
resource "aws_bedrock_model_invocation_logging_configuration" "logs" {
  logging_config {
    cloudwatch_config { log_group_name = "/aws/bedrock/model-invocations" role_arn = aws_iam_role.logs.arn }
    s3_config        { bucket_name = aws_s3_bucket.logs.bucket          role_arn = aws_iam_role.logs.arn }
    text_data_delivery_enabled = true
  }
}
```

---

## If you want to… enforce safety rules (block hate/violence/sexual content/insults)

**Use:**

* `aws_bedrock_guardrail` (define the policy)
* `aws_bedrock_guardrail_version` (publish a fixed version for prod)

**What it does:** Sets content filters and messages shown when something is blocked.
**Why:** Compliance and safer outputs.

*Minimal snippet:*

```hcl
resource "aws_bedrock_guardrail" "gr" {
  name = "my-guardrail"
  blocked_input_messaging   = "Blocked by safety filters."
  blocked_outputs_messaging = "Output blocked."
  content_policy_config {
    filters_config { type = "VIOLENCE" input_strength = "HIGH" output_strength = "HIGH" }
    filters_config { type = "HATE"     input_strength = "HIGH" output_strength = "HIGH" }
  }
}

resource "aws_bedrock_guardrail_version" "gr_v" {
  guardrail_id = aws_bedrock_guardrail.gr.id
  description  = "v1"
}
```

---

## If you want to… fine-tune a model with your data

**Use:** `aws_bedrock_custom_model` (+ a data source to look up the base model)
**What it does:** Starts a customization job and registers your custom model.
**Why:** Better accuracy for your domain.

*Minimal snippet:*

```hcl
data "aws_bedrock_foundation_model" "base" { model_id = "amazon.titan-text-express-v1" }

resource "aws_bedrock_custom_model" "cm" {
  custom_model_name     = "my-custom-model"
  job_name              = "my-customize-job-1"
  base_model_identifier = data.aws_bedrock_foundation_model.base.model_arn
  role_arn              = aws_iam_role.cm.arn
  customization_type    = "FINE_TUNING"
  training_data_config  { s3_uri = "s3://my-bucket/train.jsonl" }
  output_data_config    { s3_uri = "s3://my-bucket/out/" }
}
```

---

## If you want to… reserve capacity for low, predictable latency

**Use:** `aws_bedrock_provisioned_model_throughput`
**What it does:** Buys dedicated “model units” for a model.
**Why:** Production SLOs, steady performance.

*Minimal snippet:*

```hcl
resource "aws_bedrock_provisioned_model_throughput" "pt" {
  provisioned_model_name = "poc-pt"
  model_arn              = data.aws_bedrock_foundation_model.base.model_arn
  model_units            = 1
  commitment_duration    = "NO_COMMITMENT"
}
```

---

## If you want to… label/route usage by app or team

**Use:** `aws_bedrock_inference_profile`
**What it does:** Creates a named profile that points to a model (or cross-region profile).
**Why:** Clean billing/usage separation and easier routing.

*Minimal snippet:*

```hcl
resource "aws_bedrock_inference_profile" "ip" {
  name        = "app-profile"
  description = "Profile for my app"
  model_source { foundation_model { region = var.aws_region, model_arn = data.aws_bedrock_foundation_model.base.model_arn } }
}
```

