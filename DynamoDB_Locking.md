# Terraform State File Unlock – End-to-End Guide (DynamoDB)

## ⚡️ How to Avoid State Lock Issues

### For All Backends (Azure, AWS, etc.)

1. **Use Remote Backends with Locking Enabled**

   * Always use backends that support state locking.

2. **Avoid Running Multiple Terraform Commands Simultaneously**

   * Only one person or CI/CD job should run `terraform plan/apply/destroy` per workspace.

3. **Gracefully Stop Terraform Executions**

   * Avoid force-stopping Terraform. Let it complete naturally.

4. **Use `terraform plan -out=tfplan`**

   * Separates planning from applying, reducing lock contention.

5. **Queue or Lock CI/CD Pipeline Stages**

   * Prevent concurrent pipeline runs.

6. **Enable Monitoring**

   * Set up logs or alerts for lock errors.

7. **Train Users**

   * Ensure all team members understand lock behavior and proper practices.

---

## 🥺 Optional: Break Blob Lease (Only for Azure)

If `terraform force-unlock` fails and the lease is stuck in Azure:

```bash
az storage blob lease break \
  --container-name <container-name> \
  --blob-name <blob-name> \
  --account-name <storage-account-name> \
  --auth-mode login
```

---

## 🌐 AWS DynamoDB State Locking (S3 Backend)

### Enable DynamoDB Locking

To enable state locking for Terraform using AWS S3 + DynamoDB:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-tf-state-bucket"
    key            = "global/s3/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### Table Requirements

* **Partition key:** `LockID` (String)
* No sort key required.
* Provisioned with read/write capacity depending on usage.

### Unlocking DynamoDB Manually (only when needed)

Go to the **DynamoDB Console**, find the table, and **delete the stuck LockID** entry.

### Warning

Only manually delete a lock if you're absolutely sure no Terraform operation is in progress.

---

## 📂 References

* [Terraform CLI: `force-unlock`](https://developer.hashicorp.com/terraform/cli/commands/force-unlock)
* [Azure CLI: `az storage blob lease`](https://learn.microsoft.com/en-us/cli/azure/storage/blob/lease)
* [Terraform Remote State with S3 and DynamoDB](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
* [Terraform State Locking Docs](https://developer.hashicorp.com/terraform/language/state/locking)
