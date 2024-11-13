 [CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$JsonOutputPath = "C:\Temp\UserGroupMemberships.json",

    [Parameter(Mandatory=$false)]
    [int]$Threshold = 1000,

    [Parameter(Mandatory=$false)]
    [string]$Server = $env:LOGONSERVER -replace "\", ""

    [Parameter(Mandatory=$false)]
    [string]$SearchBase = "LDAP://$Server/example,DC=com"
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

# Define your domain controller and search base
$DomainController = "dc01.yourdomain.com"  # Replace with your AD server or domain controller hostname
$SearchBase = "LDAP://$Server/DC=example,DC=com"  # Modify to match your AD structure

# Create a DirectoryEntry object pointing to the specific domain controller
$Root = New-Object System.DirectoryServices.DirectoryEntry($SearchBase)


# Get all user accounts in the domain (including disabled ones)
Write-Host "Retrieving user accounts..." -ForegroundColor Yellow
$users = Get-ADUser -Filter * -Properties DistinguishedName, SamAccountName -Server $Server

Write-Host "Retrieved $($users.Count) user accounts." -ForegroundColor Green

# Initialize counters for progress tracking
$totalUsers = $users.Count
$counter = 0

# Initialize a list to hold users exceeding the threshold
$HighGroupUsers = @()

# Iterate over each user to determine group memberships
foreach ($user in $users) {
    $counter++

    # Display progress every 100 users
    if ($counter % 100 -eq 0) {
        Write-Host "Processed $counter out of $totalUsers users..." -ForegroundColor Cyan
    }

    # Extract user details
    $userDN = $user.DistinguishedName
    $userName = $user.SamAccountName

    # Define LDAP filter for transitive group membership using the matching rule OID
    $ldapFilter = "(&(objectClass=group)(member:1.2.840.113556.1.4.1941:=$userDN))"

    # Initialize group count
    $groupCount = 0

    # Initialize the DirectorySearcher object for LDAP querying
    $searcher = New-Object System.DirectoryServices.DirectorySearcher($Root)
    $searcher.Filter = $ldapFilter
    $searcher.SearchScope = [System.DirectoryServices.SearchScope]::Subtree
    $searcher.PageSize = 1000  # Enables paging to handle large result sets
    $searcher.PropertiesToLoad.Add("distinguishedName") | Out-Null

    try {
        # Execute the search
        $results = $searcher.FindAll()

        # Count the number of group memberships
        $groupCount = $results.Count

        # If the user is a member of >= threshold groups, add to the list
        if ($groupCount -ge $Threshold) {
            $HighGroupUsers += [PSCustomObject]@{
                "UserName" = $userName
                "GroupCount" = $groupCount
            }
        }
    }
    catch {
        # Handle any errors that occur during the search
        Write-Warning "Failed to retrieve groups for user: $userName. Error: $_"
    }
}

# Now, output the results to the console
Write-Host "`nProcessing complete. Generating console output...`n" -ForegroundColor Yellow

foreach ($user in $HighGroupUsers) {
    Write-Host "User: $($user.UserName), Total Group Memberships: $($user.GroupCount)" -ForegroundColor Cyan
}

# Convert the list to JSON
$JsonOutput = $HighGroupUsers | ConvertTo-Json -Depth 4 -Compress:$false

# Export JSON to file
try {
    # Ensure the directory exists
    $JsonDir = Split-Path -Path $JsonOutputPath
    if (-not (Test-Path -Path $JsonDir)) {
        New-Item -Path $JsonDir -ItemType Directory -Force | Out-Null
    }

    # Write the JSON string to the specified file
    Set-Content -Path $JsonOutputPath -Value $JsonOutput -Encoding UTF8
    Write-Host "`nJSON output successfully written to: $JsonOutputPath" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to write JSON output to file: $JsonOutputPath. Error: $_"
}

$TotalDuration = (Get-Date) - $startTime
Write-Host "`nTotal script execution time: $($TotalDuration.TotalSeconds) seconds." -ForegroundColor Green
