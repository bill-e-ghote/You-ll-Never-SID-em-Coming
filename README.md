# You'll Never SID'em Coming
This repository contains utility scripts designed to identify users in Active Directory who could be used to perform the SID-based denial-of-service (DoS) attack.

# The Research
https://pentera.io/resources/research/dos-attack-active-directory-sid-exploitation/

## Prerequisites

- Active Directory access with necessary privileges for running LDAP queries.
- PowerShell (for executing the provided scripts).

## Usage

1. Clone this repository to your local machine.
2. Execute the PowerShell scripts as follows:
   ```powershell
   ./Get-UserHighGroupMemberships.ps1 -JsonOutputPath OUTPUT_PATH
   ./Get-UserOUPermissions.ps1 -JsonOutputPath OUTPUT_PATH

## Disclaimer
The code described in this advisory (the “Code”) is provided on an “as is” and “as available” basis and may contain bugs, errors, and other defects. You are advised to safeguard important data and to use caution. By using this Code, you agree that Pentera shall have no liability to you for any claims in connection with the Code. Pentera disclaims any and all warranties and any and all liability for any direct, indirect, incidental, punitive, exemplary, special or consequential damages, even if Pentera or its related parties are advised of the possibility of such damages. Pentera undertakes no duty to update the Code or this advisory.
