Param(
    [Parameter(Mandatory = $true, HelpMessage = "N/A")]
    [string]$Url
)

Connect-PnPOnline -Url $Url -UseWebLogin

Apply-PnPProvisioningTemplate -Path .\template.xml