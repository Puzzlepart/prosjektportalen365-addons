param (
  [Parameter(Mandatory = $true)]
  [string]
  $Url,
  [Parameter(Mandatory = $true)]
  [string]
  $HubSiteUrl
)

# Get configuration from Azure Automation Variables (when running in automation) or use defaults
function Get-ConfigurationValue {
    param(
        [string]$VariableName,
        [string]$DefaultValue
    )
    
    if ($null -ne $PSPrivateMetadata) {
        # Running in Azure Automation context
        try {
            $value = Get-AutomationVariable -Name $VariableName -ErrorAction SilentlyContinue
            if ($null -ne $value) {
                return $value
            }
        }
        catch {
            Write-Output "Warning: Could not get automation variable '$VariableName', using default value"
        }
    }
    return $DefaultValue
}

# Get date calculation rules
$dateCalculationRulesJson = Get-ConfigurationValue -VariableName 'DateCalculationRules' -DefaultValue '{"inspectionPeriodYears":1,"waiverPeriodYears":3,"complaintPeriodYears":5}'
$dateCalculationRules = $dateCalculationRulesJson | ConvertFrom-Json
function Connect-SharePoint($Url) {
  $pnpParams = @{ 
    Url           = $Url
    ErrorAction   = "Stop"
    WarningAction = "Ignore"
  }
  if ($null -ne $PSPrivateMetadata) {
    #azure runbook context
    $pnpParams.Add("ManagedIdentity", $true)
  }
  else {
    $pnpParams.Add("UseWebLogin", $true)
    #$pnpParams.Add("ClientId", $global:__ClientId)
  }

  Connect-PnPOnline @pnpParams
}

$global:__ClientId = "da6c31a6-b557-4ac3-9994-7315da06ea3a"

Connect-SharePoint -Url $Url

$ProjectProperties = Get-PnPListItem -List "Prosjektegenskaper" -Id 1 -ErrorAction SilentlyContinue

if ($null -eq $ProjectProperties) {
  Write-Output "Prosjektegenskaper not found"
  exit
}

$CurrentDate = $ProjectProperties.FieldValues["GtcHandoverDate"]
Write-Output "Current GtcHandoverDate: $CurrentDate"

if ($null -ne $CurrentDate) {
  # Calculate new dates using configuration rules
  $GtcYearInspectionDate = (Get-Date $CurrentDate).AddYears($dateCalculationRules.inspectionPeriodYears)
  $GtcWaiverDate = (Get-Date $CurrentDate).AddYears($dateCalculationRules.waiverPeriodYears)
  $GtcComplaintDate = (Get-Date $CurrentDate).AddYears($dateCalculationRules.complaintPeriodYears)

  Write-Output "Processing date change"
  $Values = @{
    "GtcYearInspectionDate" = $GtcYearInspectionDate
    "GtcWaiverDate"         = $GtcWaiverDate
    "GtcComplaintDate"      = $GtcComplaintDate
  }
}

if ($null -ne $Values) {
  Write-Output "Values to update: $($Values | Out-String)"

  $Output = Set-PnPListItem -List "Prosjektegenskaper" -Identity 1 -Values $Values -UpdateType SystemUpdate

  Connect-SharePoint -Url $HubSiteUrl
  $MatchingProjectInHub = Get-PnPListItem -List "Prosjekter" -Query "<View><Query><Where><Eq><FieldRef Name='GtSiteUrl' /><Value Type='Text'>$Url</Value></Eq></Where></Query></View>" -ErrorAction SilentlyContinue
    
  if ($null -ne $MatchingProjectInHub) {
    Write-Output "Updating project list item in hub with new dates"
    $Output = Set-PnPListItem -List "Prosjekter" -Identity $MatchingProjectInHub -Values $Values -UpdateType SystemUpdate -ErrorAction Continue
  }
  else {
    Write-Output "`tFailed to update project list item in hub with project data - no matching project found"
  }
}
