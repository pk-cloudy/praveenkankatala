# Terraform Role Assignment

## Code in `locals.tf`

```hcl
role_assignments = flatten([
  for service, roles in var.role_mappings : [
    for role in roles : {
      service = service
      role    = role
    }
  ]
])
```

---

## 1. Understanding `var.role_mappings`

The variable `role_mappings` is a map where:

- **Key** = Service name  
- **Value** = List of roles assigned to that service

### Example

```hcl
role_mappings = {
  postgresql = [
    "Cognitive Services OpenAI User",
    "Log Analytics Reader"
  ]
}
```

This means for the service `postgresql`, Terraform will assign the following roles:

- Cognitive Services OpenAI User  
- Log Analytics Reader

---

## 2. Understanding the Terraform Expression

```hcl
role_assignments = flatten([
  for service, roles in var.role_mappings : [
    for role in roles : {
      service = service
      role    = role
    }
  ]
])
```

### Breakdown:

- **Step 1: Outer loop**  
  Iterates over the `var.role_mappings` map.  
  `service` = key (e.g., "postgresql")  
  `roles` = list of role names

- **Step 2: Inner loop**  
  For each `role` in `roles`, it creates:
  ```hcl
  {
    service = service
    role    = role
  }
  ```
**role is just a placeholder name for the current role string in the list of roles for a service.
Terraform uses it to build an object like { service = "redis", role = "Reader" }**

- **Step 3: Flatten**  
  Flattens the nested lists into a single list of objects.
  Now we take those nested lists and merge them into one single list:

 **Before flatten**

```hcl
[
  [ {service="postgresql", role="Reader"},                {service="postgresql", role="Website Contributor"} ],
  [ {service="redis",      role="Reader"},                {service="redis",      role="Cache Contributor"}    ],
  [ {service="frontend",   role="Reader"} ]
]
```
**After flatten**

```hcl
[
  {service="postgresql", role="Reader"},
  {service="postgresql", role="Website Contributor"},
  {service="redis",      role="Reader"},
  {service="redis",      role="Cache Contributor"},
  {service="frontend",   role="Reader"}
]
```
---

## 3. Execution Breakdown

### Example Input

```hcl
role_mappings = {
  postgresql = ["Cognitive Services OpenAI User", "Log Analytics Reader"]
  redis      = ["Redis Cache Contributor", "Reader"]
}
```

### Terraform Steps

- **Outer loop:**
- for service, roles in var.role_mappings :
  Terraform goes through each entry in the map one by one.
  - Iteration 1:  
    `service = "postgresql"`  
    `roles = ["Cognitive Services OpenAI User", "Log Analytics Reader"]`
  - Iteration 2:  
    `service = "redis"`  
    `roles = ["Redis Cache Contributor", "Reader"]`

- **Inner loop results:**
  ```hcl
  [
  for role in roles : {
    service = service
    role    = role
  }
  ]
  ```

- Now, for the current service (e.g. `"redis"`) and its list of roles:
- It loops through **each role** in that list.
- For **each role**, it builds an object that includes:
  - the **current service name**
  - the **current role name**


  ```hcl
  { service = "postgresql", role = "Cognitive Services OpenAI User" },
  { service = "postgresql", role = "Log Analytics Reader" },
  { service = "redis", role = "Redis Cache Contributor" },
  { service = "redis", role = "Reader" }
  ```

---

## 4. Final Output

The final `role_assignments` list:

| Service    | Role                            |
|------------|---------------------------------|
| postgresql | Cognitive Services OpenAI User  |
| postgresql | Log Analytics Reader            |
| redis      | Redis Cache Contributor         |
| redis      | Reader                          |

---

## Code in `main.tf`
**Assigne User Identity**

```hcl
resource "azurerm_user_assigned_identity" "service_identity" {
  for_each            = toset(var.services)
  name                = "${each.key}-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
}
```

### Explanation

- Declares a managed identity per service:
  ```hcl
  for_each = toset(var.services)
  ```
  Converts the list into a set to ensure uniqueness.

- **Naming:**
  ```hcl
  name = "${each.key}-identity"
  ```
  Examples:
  - `postgresql-identity`
  - `redis-identity`

**Role Assignment**

```hcl
resource "azurerm_role_assignment" "role_assignment" {
  for_each = {
    for ra in local.role_assignments :
    "${ra.service}-${ra.role}" => ra
  }

  scope                = lookup(local.resource_scopes, each.value.service, null)
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.service_identity[each.value.service].principal_id
}
```

### Explanation

`local.role_assignments` is a list of maps, each map contains:

- `service`
- `role`

### `for_each` block:

Whenever you use a `for_each` on a resource, Terraform exposes two handy iteration variables inside that block:

- **`each.key`** — the map key for the current iteration  
- **`each.value`** — the map value for the current iteration  

---

## Example `for_each` Map

In your case, you built your `for_each` map like this:

```hcl
for_each = {
  for ra in local.role_assignments :
  "${ra.service}-${ra.role}" => ra
}
```

This comprehension does two things:

1. **Key**  
   ```hcl
   "${ra.service}-${ra.role}"
   ```  
   — a string combining the service name and role name, e.g. `"redis-Reader"`.

2. **Value**  
   ```hcl
   ra
   ```  
   — the entire object from `local.role_assignments`, e.g.:

   ```hcl
   {
     service = "redis"
     role    = "Reader"
   }
   ```

---

## What Happens During Each Iteration

For each entry in the map:

1. **`each.key`**  
   Might be:  
   ```hcl
   "redis-Reader"
   ```

2. **`each.value`**  
   Is the object:  
   ```hcl
   {
     service = "redis"
     role    = "Reader"
   }
   ```

---

## Accessing the Role

Because `each.value` holds an object with a field called `role`, you can refer to it directly:

```hcl
role_definition_name = each.value.role
```
- In Terraform’s HCL, the => operator is what you use to define a key‐value pair inside a map
### Why a map?

`for_each` requires unique keys to track changes.  
Using `service-role` ensures:

- **Uniqueness**: No duplicate role assignments for the same service  
- **Stability**: Reordering or adding new entries doesn’t break existing state

### Resulting structure:

```hcl
{
  "redis-Reader"                  = { service = "redis", role = "Reader" }
  "redis-Redis Cache Contributor" = { service = "redis", role = "Redis Cache Contributor" }
  "frontend-Reader"               = { service = "frontend", role = "Reader" }
  ...
}
```
---
### Understanding lookup
In Terraform, the built-in `lookup()` function is used to safely retrieve a value from a map.

### Syntax

```hcl
lookup(map, key, default)
```

This function takes **three arguments**:

---

### 1. `map`

The map you want to search.  
In your case, it's `local.resource_scopes`, which might look like this:

```hcl
{
  postgresql = azurerm_postgresql_flexible_server.postgres.id
  redis      = azurerm_redis_cache.redis.id
  # ...more services
}
```

---

### 2. `key`

The key (string) you’re trying to look up in the map.  
Here, it's:

```hcl
each.value.service
```

Which refers to the name of the current service in your `for_each` loop, such as `"redis"` or `"frontend"`.

---

### 3. `default`

This is the value Terraform will return **if the key isn’t found** in the map.  
For example:

```hcl
lookup(local.resource_scopes, each.value.service, null)
```

- If the key **is found**, it returns the corresponding resource ID.
- If the key **is not found**, it returns `null` instead of throwing an error.

---
## `azurerm_user_assigned_identity.service_identity`

This refers to the group of managed identities you created using `for_each`.

### Example

```hcl
resource "azurerm_user_assigned_identity" "service_identity" {
  for_each = toset(var.services)
  name     = "${each.key}-identity"
  ...
}
```

---

## `[each.value.service]`

This selects the identity for the current service name.

### Example

If `each.value.service == "redis"`, then this points to:

```hcl
azurerm_user_assigned_identity.service_identity["redis"]
```

---

## `.principal_id`

This gets the **object ID** of that identity in Azure Active Directory.  
It’s the unique identifier that Azure uses to **grant permissions** (like assigning roles).

---
## Field Explanations

- **`scope`**  
  ```hcl
  scope = lookup(local.resource_scopes, each.value.service, null)
  ```  
  Looks up the resource ID from `local.resource_scopes` using the service name.

- **`role_definition_name`**  
  ```hcl
  role_definition_name = each.value.role
  ```  
  Uses the role name (e.g., `"Reader"`, `"Contributor"`)

- **`principal_id`**  
  ```hcl
  principal_id = azurerm_user_assigned_identity.service_identity[each.value.service].principal_id
  ```  
  Retrieves the principal ID of the managed identity associated with the service.

---
