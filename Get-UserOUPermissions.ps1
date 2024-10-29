 [CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$JsonOutputPath = "C:\Temp\UserOUPermissions.json"
)

# Check if Active Directory module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Host "Active Directory module not found. Please install RSAT or run on a domain controller." -ForegroundColor Red
    exit
}

# Import the Active Directory module
Import-Module ActiveDirectory

# Start timer
$startTime = Get-Date

# Get all OUs in the domain
Write-Host "Retrieving Organizational Units..." -ForegroundColor Yellow
$OUs = Get-ADOrganizationalUnit -Filter * -Properties DistinguishedName | Select-Object -ExpandProperty DistinguishedName

$endTime = Get-Date
$duration = $endTime - $startTime
Write-Host "Retrieved $($OUs.Count) OUs in $($duration.TotalSeconds) seconds." -ForegroundColor Green

# Initialize the hashtable to store permissions per user/group
$UserPermissions = @{}

# Define the GUID for group object class
$GroupGUID = "bf967a9c-0de6-11d0-a285-00aa003049e2"

$TotalOUs = $OUs.Count
$Counter = 0

foreach ($OU_DN in $OUs) {
    $Counter++
    if ($Counter % 100 -eq 0) {
        Write-Host "Processed $Counter out of $TotalOUs OUs..." -ForegroundColor Cyan
    }

    Write-Verbose "Processing OU ${Counter}: $OU_DN"

    try {
        # Get the ACL of the OU
        $acl = Get-ACL -Path "AD:\$OU_DN"
        $Owner = $acl.Owner

        # Ensure the Owner is in the hashtable
        if (-not $UserPermissions.ContainsKey($Owner)) {
            $UserPermissions[$Owner] = @{
                "Owner" = @()
                "Full Control" = @()
                "Create Groups" = @()
            }
            Write-Verbose "Added new entity: $Owner"
        }

        # Add the OU to the Owner's "Owner" list, if not already present
        if (-not ($UserPermissions[$Owner]["Owner"] -contains $OU_DN)) {
            $UserPermissions[$Owner]["Owner"] += $OU_DN
            Write-Verbose "Added OU to $Owner's Owner list: $OU_DN"
        }

        # Get the ACLs for the OU
        $ACLs = $acl.Access

        foreach ($ACE in $ACLs) {
            # Process only Allow ACEs
            if ($ACE.AccessControlType -eq "Allow") {
                $Identity = $ACE.IdentityReference.Value

                # Ensure the Identity is in the hashtable
                if (-not $UserPermissions.ContainsKey($Identity)) {
                    $UserPermissions[$Identity] = @{
                        "Owner" = @()
                        "Full Control" = @()
                        "Create Groups" = @()
                    }
                    Write-Verbose "Added new entity: $Identity"
                }

                # Check for Full Control (GenericAll)
                if (($ACE.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll) -ne 0) {
                    if (-not ($UserPermissions[$Identity]["Full Control"] -contains $OU_DN)) {
                        $UserPermissions[$Identity]["Full Control"] += $OU_DN
                        Write-Verbose "Added OU to $Identity's Full Control list: $OU_DN"
                    }
                }

                # Check for Create Groups (CreateChild on group objects)
                if (($ACE.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::CreateChild) -ne 0) {
                    # Check if ObjectType matches group object GUID
                    if ($ACE.ObjectType -eq $GroupGUID) {
                        if (-not ($UserPermissions[$Identity]["Create Groups"] -contains $OU_DN)) {
                            $UserPermissions[$Identity]["Create Groups"] += $OU_DN
                            Write-Verbose "Added OU to $Identity's Create Groups list: $OU_DN"
                        }
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to process OU: $OU_DN. Error: $_"
    }
}

# Now, output the results to the console
Write-Host "Processing complete. Generating console output...`n" -ForegroundColor Yellow

foreach ($User in $UserPermissions.Keys) {
    Write-Host "Entity: $User" -ForegroundColor Cyan

    foreach ($PermissionType in @("Full Control", "Create Groups", "Owner")) {
        $OUsList = $UserPermissions[$User][$PermissionType]

        if ($OUsList -and $OUsList.Count -gt 0) {
            Write-Host "- ${PermissionType}:"
            foreach ($OU in $OUsList | Sort-Object) {
                Write-Host "    - $OU"
            }
        }
    }
    Write-Host
}

# Convert the hashtable to a structured object for JSON serialization
Write-Host "Generating JSON output..." -ForegroundColor Yellow

# Create an array to hold each entity's permissions in a structured format
$JsonOutput = @()

foreach ($User in $UserPermissions.Keys) {
    $Entity = [PSCustomObject]@{
        "Entity" = $User
        "Permissions" = [PSCustomObject]@{
            "Full Control" = $UserPermissions[$User]["Full Control"]
            "Create Groups" = $UserPermissions[$User]["Create Groups"]
            "Owner" = $UserPermissions[$User]["Owner"]
        }
    }
    $JsonOutput += $Entity
}

# Convert to JSON with proper formatting
$JsonString = $JsonOutput | ConvertTo-Json -Depth 4 -Compress:$false

# Output JSON to file
try {
    # Ensure the directory exists
    $JsonDir = Split-Path -Path $JsonOutputPath
    if (-not (Test-Path -Path $JsonDir)) {
        New-Item -Path $JsonDir -ItemType Directory -Force | Out-Null
    }

    # Write the JSON string to the specified file
    Set-Content -Path $JsonOutputPath -Value $JsonString -Encoding UTF8
    Write-Host "JSON output successfully written to: $JsonOutputPath" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to write JSON output to file: $JsonOutputPath. Error: $_"
}

$TotalDuration = (Get-Date) - $startTime
Write-Host "Total script execution time: $($TotalDuration.TotalSeconds) seconds." -ForegroundColor Green
