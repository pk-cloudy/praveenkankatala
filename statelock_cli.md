# Terraform State File Unlock – End-to-End Guide (Azure Blob Storage)

## 📌 Purpose

This document provides detailed steps to identify and resolve a locked Terraform state file, specifically when using Azure Blob Storage as the backend. This is commonly needed when a Terraform process was interrupted and the state file remains locked.

---

## 🔐 Background: Terraform State Locking

Terraform uses a locking mechanism to prevent concurrent changes to the state file. If a process crashes or is forcibly stopped, the lock may not be released. This results in the error:

```
Error acquiring the state lock
```

Or:

```
Error: executing request: unexpected status 412
There is currently a lease on the blob and no lease ID was specified in the request.
```

---

## 🔄 Unlock Workflow

### Step 1: 📂 Navigate to the Terraform Working Directory

Ensure you are in the directory where your `.tf` files and the `.terraform` folder reside:

```bash
cd ~/path/to/terraform/project
```

---

### Step 2: ❓ Verify Locking Error

When running Terraform commands (like `plan`, `apply`, or `destroy`), you might see:

```
Error: Error acquiring the state lock
```

Or:

```
There is currently a lease on the blob and no lease ID was specified in the request.
```

---

### Step 3: 🔎 Get Lock ID from Azure Blob Metadata

Use the following command to retrieve the lock metadata from the Azure Blob backend:

```bash
az storage blob metadata show \
  --container-name <container-name> \
  --name <state-file-name> \
  --account-name <storage-account-name> \
  --auth-mode login
```

**Example:**

```bash
az storage blob metadata show \
  --container-name tfstate \
  --name prod.terraform.tfstate \
  --account-name mytfstorage \
  --auth-mode login
```

Look for:

```json
"terraformlockid": "b632a0f0-0534-634e-d980-2bb7f291d114"
```

✅ This is the **Lock ID** you need.

---

### Step 4: 🔓 Force Unlock the State

Once you have the lock ID, run:

```bash
terraform force-unlock b632a0f0-0534-634e-d980-2bb7f291d114
```

Terraform will prompt for confirmation:

```
Do you really want to force-unlock?
```

Type:

```
yes
```

✅ You’ll see:

```
Terraform state has been successfully unlocked!
```

---

### Step 5: ✅ Confirm Unlock

Try running your original `terraform plan` or `apply` again to confirm that the lock has been cleared.

---

## ⚠️ Best Practices

| Do’s ✅                                | Don’ts ❌                                           |
| ------------------------------------- | -------------------------------------------------- |
| Ensure no one else is using the state | Never force-unlock if someone is running Terraform |
| Use `terraform force-unlock`          | Don’t break blob lease manually unless necessary   |
| Store state in a secure backend       | Don’t manipulate `.tfstate` manually               |

---

## 🥺 Optional: Break Blob Lease (Only if necessary)

If `terraform force-unlock` fails and the lease is stuck (e.g., 412 errors), use Azure CLI:

```bash
az storage blob lease break \
  --container-name <container-name> \
  --blob-name <blob-name> \
  --account-name <storage-account-name> \
  --auth-mode login
```

---

## 📂 References

* [Terraform CLI: `force-unlock`](https://developer.hashicorp.com/terraform/cli/commands/force-unlock)
* [Azure CLI: `az storage blob lease`](https://learn.microsoft.com/en-us/cli/azure/storage/blob/lease)
