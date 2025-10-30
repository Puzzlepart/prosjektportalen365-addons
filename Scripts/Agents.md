# AGENTS.md

## Project Overview
PowerShell scripts for SharePoint Online automation using PowerShell 7 with PnP.PowerShell 3.1.0. Focus areas: project management, AI integration, and SharePoint site operations. Utility scripts for Prosjektportalen (https://github.com/Puzzlepart/prosjektportalen365).

## Prosjektportalen Overview
Prosjektportalen is a Microsoft 365 solution consisting of the following modules
- A Prosjektportalen hub site with overview of all projects. Project information is stored in a list "Projects" and project status is stored in a list "Prosjektstatus" with a reference to project by SiteId (one entry per report per project)
- Multiple project sites, setup as their own Microsoft 365 sites with additiona lists, pages and web parts. Project information is stored in a list "Prosjektegenskaper". "Project status" information is only stored in the hub list "Prosjektstatus"
- App catalog with multiple app packages from Prosjektportalen

## Setup Commands
- Install PnP.PowerShell: `Install-Module -Name PnP.PowerShell -RequiredVersion 3.1.0 -Force -AllowClobber`
- Connect to SharePoint: `Connect-PnPOnline -Url "https://tenant.sharepoint.com/sites/sitename" -Interactive`
- Test connection: `Get-PnPWeb`
- Admin site URL can be found from any given URL by adding -admin to hostname. E.g. admin site from the URL "https://tenant.sharepoint.com/sites/sitename" is "https://tenant-admin.sharepoint.com/"

## Authentication Methods
- **Production**: Use `-ClientId` with browser-based auth and `-ManagedIdentity` for Azure Automation
- **Credentials**: Store OpenAI keys using `Add-PnPStoredCredential -Name "openai_api"` or Azure Automation credentials

## Code Patterns
- Always check `$null -ne $PSPrivateMetadata` to detect Azure Automation context
- Use `Connect-SharePoint` wrapper function for consistent connection handling
- Implement retry logic with `Invoke-AgentWithRetry` for SharePoint operations
- Batch operations when processing multiple list items
- Use `Write-AgentLog` for consistent logging across scripts

## Common Operations
- List items: `Get-PnPListItem -List "ListName" -PageSize 100`
- Add items: `Add-PnPListItem -List "ListName" -Values @{Title="Value"}`
- Field metadata: `Get-PnPField -List "ListName"`
- Site info: `Get-PnPSite` and `Get-PnPWeb`
- Users: `Get-PnPMicrosoft365GroupMember -Identity $GroupId`

## AI Integration
- OpenAI credentials stored in credential manager or Azure Automation
- Use JSON response format for structured data: `response_format = @{type = 'json_object'}`
- Temperature 0.1 for consistent results
- Include field validation prompts for SharePoint list operations

## Error Handling
- Use `try/catch/finally` blocks
- Implement exponential backoff for rate limiting
- Log errors with context information
- Validate SharePoint connection before operations
- Handle null/empty responses gracefully

## Testing Instructions
- Test authentication methods in isolation
- Verify SharePoint permissions before bulk operations
- Use small test datasets before production runs
- Validate AI responses before applying to SharePoint
- Test retry logic with intentional failures

## Security Notes
- Never hardcode credentials or tenant URLs
- Use minimal required SharePoint permissions
- Validate all user inputs before SharePoint operations
- Store sensitive data in secure credential stores
- Audit AI prompts for sensitive information leakage
