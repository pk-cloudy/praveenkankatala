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
1. Understanding var.role_mappings
The variable role_mappings is a map where:

Key = Service name

Value = List of roles assigned to that service

Example
hcl
Copy
Edit
role_mappings = {
  postgresql = [
    "Cognitive Services OpenAI User",
    "Log Analytics Reader"
  ]
}
This means for the service postgresql, Terraform will assign the following roles:

Cognitive Services OpenAI User

Log Analytics Reader

2. Understanding the Terraform Expression
hcl
Copy
Edit
role_assignments = flatten([
  for service, roles in var.role_mappings : [
    for role in roles : {
      service = service
      role    = role
    }
  ]
])
Breakdown:
Step 1: Outer loop
Iterates over the var.role_mappings map.
service = key (e.g., "postgresql")
roles = list of role names

Step 2: Inner loop
For each role in roles, it creates:

hcl
Copy
Edit
{
  service = service
  role    = role
}
Step 3: Flatten
Flattens the nested lists into a single list of objects.

3. Execution Breakdown
Example Input
hcl
Copy
Edit
role_mappings = {
  postgresql = ["Cognitive Services OpenAI User", "Log Analytics Reader"]
  redis      = ["Redis Cache Contributor", "Reader"]
}
Terraform Steps
Outer loop:

Iteration 1:
service = "postgresql"
roles = ["Cognitive Services OpenAI User", "Log Analytics Reader"]

Iteration 2:
service = "redis"
roles = ["Redis Cache Contributor", "Reader"]

Inner loop results:

h
Copy
Edit
{ service = "postgresql", role = "Cognitive Services OpenAI User" },
{ service = "postgresql", role = "Log Analytics Reader" },
{ service = "redis", role = "Redis Cache Contributor" },
{ service = "redis", role = "Reader" }
4. Final Output
The final role_assignments list:

Service	Role
postgresql	Cognitive Services OpenAI User
postgresql	Log Analytics Reader
redis	Redis Cache Contributor
redis	Reader

Code in main.tf
hcl
Copy
Edit
resource "azurerm_role_assignment" "role_assignment" {
  for_each = {
    for ra in local.role_assignments :
    "${ra.service}-${ra.role}" => ra
  }

  scope                = lookup(local.resource_scopes, each.value.service, null)
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.service_identity[each.value.service].principal_id
}
Explanation
local.role_assignments is a list of maps, each map contains:

service

role

for_each block:
hcl
Copy
Edit
for_each = {
  for ra in local.role_assignments :
  "${ra.service}-${ra.role}" => ra
}
Key = "${ra.service}-${ra.role}" (e.g., "redis-Reader")

Value = whole ra object

Why a map?
for_each requires unique keys to track changes.
Using service-role ensures:

Uniqueness: No duplicate role assignments for the same service

Stability: Reordering or adding new entries doesn’t break existing state

Resulting structure:
hcl
Copy
Edit
{
  "redis-Reader"                  = { service = "redis", role = "Reader" }
  "redis-Redis Cache Contributor" = { service = "redis", role = "Redis Cache Contributor" }
  "frontend-Reader"               = { service = "frontend", role = "Reader" }
  ...
}
Field Explanations
scope

hcl
Copy
Edit
scope = lookup(local.resource_scopes, each.value.service, null)
Looks up the resource ID from local.resource_scopes using the service name.

role_definition_name

hcl
Copy
Edit
role_definition_name = each.value.role
Uses the role name (e.g., "Reader", "Contributor")

principal_id

hcl
Copy
Edit
principal_id = azurerm_user_assigned_identity.service_identity[each.value.service].principal_id
Retrieves the principal ID of the managed identity associated with the service.

Code in user_assigned_identity.tf
hcl
Copy
Edit
resource "azurerm_user_assigned_identity" "service_identity" {
  for_each            = toset(var.services)
  name                = "${each.key}-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
}
Explanation
Declares a managed identity per service:

hcl
Copy
Edit
for_each = toset(var.services)
Converts the list into a set to ensure uniqueness.

Naming:

hcl
Copy
Edit
name = "${each.key}-identity"
Examples:

postgresql-identity

redis-identity
