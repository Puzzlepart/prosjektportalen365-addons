# This script requires the Microsoft Graph PowerShell module to be installed. It assigns the necessary permissions to a managed identity to access Microsoft Graph and SharePoint Online.

$ManagedIdentityId = "73bc3a50-c895-4bcb-88d3-e7ae9a99084b" # Object (principal) ID of managed identity

$GraphPermissionScopes = @(
  "Directory.ReadWrite.All"
  "Group.ReadWrite.All"
  "GroupMember.ReadWrite.All"
  "User.ReadWrite.All"
  "RoleManagement.ReadWrite.Directory"
)

Connect-MgGraph -Scopes "Application.Read.All", "AppRoleAssignment.ReadWrite.All,RoleManagement.ReadWrite.Directory"

$ManagedIdentity = Get-MgServicePrincipal -ServicePrincipalId $ManagedIdentityId

if ($null -eq $ManagedIdentity) {
  Write-Host "Managed identity not found"
  exit
}
$GraphServicePrincipal = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"

foreach ($PermissionScope in $GraphPermissionScopes) {
  $appRole = $GraphServicePrincipal.AppRoles | Where-Object Value -eq $PermissionScope | Where-Object AllowedMemberTypes -contains "Application"

  $bodyParam = @{
    PrincipalId = $managedIdentityId
    ResourceId  = $GraphServicePrincipal.Id
    AppRoleId   = $appRole.Id
  }
  New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentityId -BodyParameter $bodyParam
}

$SharePointApp = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0ff1-ce00-000000000000'"

$SharePointPermissionScopes = @(
  'Sites.FullControl.All',
  'TermStore.ReadWrite.All',
  'User.ReadWrite.All'
)

ForEach ($PermissionScope in $SharePointPermissionScopes) {
  $appRole = $SharePointApp.AppRoles | Where-Object { $_.Value -eq $PermissionScope }
  
  $bodyParam = @{
    PrincipalId = $managedIdentityId
    ResourceId  = $SharePointApp.Id
    AppRoleId   = $appRole.Id
  }

  New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentityId -BodyParameter $bodyParam
}