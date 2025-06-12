# Define variables
$instance = "" # e.g., "dev12345"
$username = ""
$password = ""
$table = "incident" # The table you want to query, e.g., "incident" for incidents
$assignmentGroup = "Development Team Group" # e.g., "Network Support"

# Define the state you want to filter by
$state = "2"  # Replace "2" with the actual value for the "In Progress" state in your instance

# Create the query parameter
$query = "state=$state"

# Create the URI with the query parameter for filtering by state
$uri = "https://$instance.service-now.com/api/now/table/sc_task?sysparm_query=$query"

# Debug: Print the URI to ensure it's correct
Write-Host "ServiceNow URI: $uri"

# Create the credential object
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)

# Define headers
$headers = @{
    "Accept" = "application/json"
}

try {
    # Perform the REST API call
    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -Credential $credential
    
    # Debug: Print the raw response
    Write-Host "Raw Response: $($response | ConvertTo-Json -Depth 10)"

    # Check if the response contains results
    if ($response.result) {
        # Loop through each result and display ticket information
        foreach ($ticket in $response.result) {
            Write-Host "Ticket Number: $($ticket.number)"
            Write-Host "Short Description: $($ticket.short_description)"
            Write-Host "State: $($ticket.state)"
            Write-Host "Priority: $($ticket.priority)"
            Write-Host "Assigned To: $($ticket.assigned_to.display_value)"
            Write-Host "Created: $($ticket.sys_created_on)"
            Write-Host "Updated: $($ticket.sys_updated_on)"
            Write-Host "-----------------------------------"
        }
    } else {
        Write-Host "No tickets found."
    }
} catch {
    Write-Host "An error occurred:"
    Write-Host $_.Exception.Message
    Write-Host $_.Exception.Response.Content
}
