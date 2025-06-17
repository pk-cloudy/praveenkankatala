# Terraform Role Assignment Automation Documentation

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

- **Step 3: Flatten**  
  Flattens the nested lists into a single list of objects.
  Now we take those nested lists and merge them into one single list:

 ## Before flatten

```hcl
[
  [ {service="postgresql", role="Reader"},                {service="postgresql", role="Website Contributor"} ],
  [ {service="redis",      role="Reader"},                {service="redis",      role="Cache Contributor"}    ],
  [ {service="frontend",   role="Reader"} ]
]
```
## After flatten

```hcl
[
  {service="postgresql", role="Reader"},
  {service="postgresql", role="Website Contributor"},
  {service="redis",      role="Reader"},
  {service="redis",      role="Cache Contributor"},
  {service="frontend",   role="Reader"}
]
```
flatten concatenates all the inner lists end-to-end, giving you one big list of service/role objects that you can loop over in a single for_each.

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
  - Iteration 1:  
    `service = "postgresql"`  
    `roles = ["Cognitive Services OpenAI User", "Log Analytics Reader"]`
  - Iteration 2:  
    `service = "redis"`  
    `roles = ["Redis Cache Contributor", "Reader"]`

- **Inner loop results:**
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

## Code in `user_assigned_identity.tf`

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

## Code in `locals.tf` (Resource Scopes)

```hcl
resource_scopes = {
  postgresql            = azurerm_postgresql_flexible_server.postgres.id
  redis                 = azurerm_redis_cache.redis.id
  frontend              = azurerm_linux_web_app.frontend.id
  backend               = azurerm_linux_web_app.backend.id
  celery                = azurerm_linux_web_app.celery.id
  storage               = azurerm_storage_account.azure_storage.id
  keyvault              = azurerm_key_vault.key_vault.id
  cognitive_search      = azurerm_search_service.cog_search.id
  document_intelligence = azurerm_cognitive_account.form_recognizer.id
  content_safety        = azurerm_cognitive_account.content_safety.id
  app_gateway           = azurerm_application_gateway.app_gateway.id
  ai_language           = azurerm_cognitive_account.ai_language.id
  logicapp              = azurerm_logic_app_standard.logic_app.id
}
```

---

## Variables for Services and Role Mappings

### `services`

```hcl
variable "services" {
  description = "List of services requiring User Assigned Identities"
  type        = list(string)
  default     = [
    "postgresql",
    "redis",
    "frontend",
    "backend",
    "celery",
    "storage",
    "keyvault",
    "cognitive_search",
    "document_intelligence",
    "content_safety",
    "app_gateway",
    "ai_language",
    "logicapp"
  ]
}
```

### `role_mappings`

```hcl
variable "role_mappings" {
  description = "Mapping of services to roles"
  type = map(list(string))
  default = {
    postgresql = [
      "Cognitive Services OpenAI User",
      "Log Analytics Reader",
      "Reader",
      "Website Contributor"
    ],
    redis = [
      "Cognitive Services OpenAI User",
      "Redis Cache Contributor",
      "Log Analytics Reader",
      "Reader",
      "Website Contributor"
    ],
    frontend = [
      "Cognitive Services OpenAI User",
      "Log Analytics Reader",
      "Reader",
      "Website Contributor"
    ],
    backend = [
      "Cognitive Services OpenAI User",
      "Log Analytics Reader",
      "Reader",
      "Website Contributor"
    ],
    celery = [
      "Cognitive Services OpenAI User",
      "Log Analytics Reader",
      "Reader",
      "Website Contributor"
    ],
    storage = [
      "Cognitive Services OpenAI User",
      "Log Analytics Reader",
      "Reader",
      "Website Contributor"
    ],
    keyvault = [
      "Cognitive Services OpenAI User",
      "Log Analytics Reader",
      "Reader",
      "Website Contributor"
    ],
    cognitive_search = [
      "Cognitive Services OpenAI User",
      "Search Service Contributor",
      "Log Analytics Reader",
      "Reader",
      "Website Contributor"
    ],
    document_intelligence = [
      "Cognitive Services OpenAI User",
      "Search Service Contributor",
      "Log Analytics Reader",
      "Reader",
      "Website Contributor"
    ],
    content_safety = [
      "Cognitive Services OpenAI User",
      "Search Service Contributor",
      "Log Analytics Reader",
      "Reader",
      "Website Contributor"
    ],
    app_gateway = [
      "Cognitive Services OpenAI User",
      "Log Analytics Reader",
      "Reader",
      "Website Contributor"
    ],
    ai_language = [
      "Cognitive Services OpenAI User",
      "Search Service Contributor",
      "Log Analytics Reader",
      "Reader",
      "Website Contributor"
    ],
    logicapp = [
      "Logic Apps Standard Developer (Preview)",
      "Logic Apps Standard Contributor (Preview)"      
    ] 
  }
}
```
