param(
  [Parameter(Mandatory=$false)]
  [ValidateNotNullOrEmpty()]
  [string]$ManagedIdentityId = "dace42bb-bd05-4d56-8dfc-c121ad2a65c9" # Object (principal) ID of managed identity 
)

# This script requires the Microsoft Graph PowerShell module to be installed. It assigns the necessary permissions to a managed identity to access Microsoft Graph and SharePoint Online.

$ErrorActionPreference = "Stop"

$GraphPermissionScopes = @(
  "Directory.ReadWrite.All",
  "Group.ReadWrite.All",
  "GroupMember.ReadWrite.All",
  "User.ReadWrite.All",
  "Sites.FullControl.All",
  "RoleManagement.ReadWrite.Directory"
)
$SharePointPermissionScopes = @(
  "Sites.FullControl.All",
  "TermStore.ReadWrite.All",
  "User.ReadWrite.All"
)

try {
  Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
  Connect-MgGraph -Scopes "Application.Read.All,AppRoleAssignment.ReadWrite.All,RoleManagement.ReadWrite.Directory" -ErrorAction Stop
  Write-Host "Connected successfully" -ForegroundColor Green
  
  $context = Get-MgContext
  $organization = Get-MgOrganization
  
  Write-Host "`nCurrent Microsoft Graph Context:" -ForegroundColor Cyan
  Write-Host "  Organization: $($organization.DisplayName)" -ForegroundColor White
  Write-Host "  Tenant ID: $($context.TenantId)" -ForegroundColor White
  Write-Host "  Account: $($context.Account)" -ForegroundColor White
  
  $confirmation = Read-Host "`nIs this the correct environment? (Y/N)"
  if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "Script cancelled by user" -ForegroundColor Yellow
    Disconnect-MgGraph | Out-Null
    exit 0
  }
}
catch {
  Write-Error "Failed to connect to Microsoft Graph $_"
  exit 1
}

try {
  Write-Host "`nRetrieving managed identity..." -ForegroundColor Cyan
  $ManagedIdentity = Get-MgServicePrincipal -ServicePrincipalId $ManagedIdentityId -ErrorAction Stop
  Write-Host "Found managed identity $($ManagedIdentity.DisplayName)" -ForegroundColor Green
}
catch {
  Write-Error "Managed identity not found $_"
  Disconnect-MgGraph | Out-Null
  exit 1
}

try {
  $GraphServicePrincipal = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'" -ErrorAction Stop
}
catch {
  Write-Error "Failed to retrieve Microsoft Graph service principal $_"
  Disconnect-MgGraph | Out-Null
  exit 1
}

Write-Host "`nAssigning Microsoft Graph permissions..." -ForegroundColor Cyan
foreach ($PermissionScope in $GraphPermissionScopes) {
  $appRole = $GraphServicePrincipal.AppRoles | Where-Object Value -eq $PermissionScope | Where-Object AllowedMemberTypes -contains "Application"

  if ($null -eq $appRole) {
    Write-Warning "Permission scope '$PermissionScope' not found in Microsoft Graph"
    continue
  }

  # Check if permission is already assigned
  $existingAssignment = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ManagedIdentityId | Where-Object { $_.AppRoleId -eq $appRole.Id -and $_.ResourceId -eq $GraphServicePrincipal.Id }
  
  if ($existingAssignment) {
    Write-Host "$PermissionScope - Already assigned" -ForegroundColor Yellow
  }
  else {
    try {
      $bodyParam = @{
        PrincipalId = $ManagedIdentityId
        ResourceId  = $GraphServicePrincipal.Id
        AppRoleId   = $appRole.Id
      }
      New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ManagedIdentityId -BodyParameter $bodyParam -ErrorAction Stop | Out-Null
      Write-Host "$PermissionScope - Assigned successfully" -ForegroundColor Green
    }
    catch {
      Write-Warning "Failed to assign $PermissionScope $_"
    }
  }
}

try {
  $SharePointApp = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0ff1-ce00-000000000000'" -ErrorAction Stop
}
catch {
  Write-Error "Failed to retrieve SharePoint service principal $_"
  Disconnect-MgGraph | Out-Null
  exit 1
}

Write-Host "`nAssigning SharePoint permissions..." -ForegroundColor Cyan
foreach ($PermissionScope in $SharePointPermissionScopes) {
  $appRole = $SharePointApp.AppRoles | Where-Object { $_.Value -eq $PermissionScope }
  
  if ($null -eq $appRole) {
    Write-Warning "Permission scope '$PermissionScope' not found in SharePoint"
    continue
  }

  # Check if permission is already assigned
  $existingAssignment = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ManagedIdentityId | Where-Object { $_.AppRoleId -eq $appRole.Id -and $_.ResourceId -eq $SharePointApp.Id }
  
  if ($existingAssignment) {
    Write-Host "$PermissionScope - Already assigned" -ForegroundColor Yellow
  }
  else {
    try {
      $bodyParam = @{
        PrincipalId = $ManagedIdentityId
        ResourceId  = $SharePointApp.Id
        AppRoleId   = $appRole.Id
      }
      New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ManagedIdentityId -BodyParameter $bodyParam -ErrorAction Stop | Out-Null
      Write-Host "$PermissionScope - Assigned successfully" -ForegroundColor Green
    }
    catch {
      Write-Warning "Failed to assign $PermissionScope $_"
    }
  }
}

Write-Host "`nDisconnecting from Microsoft Graph..." -ForegroundColor Cyan
Disconnect-MgGraph | Out-Null
Write-Host "Script completed successfully" -ForegroundColor Green