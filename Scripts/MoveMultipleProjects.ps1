$ProjectsToMove = @(
    "https://xxx.sharepoint.com/sites/project1",
    "https://xxx.sharepoint.com/sites/project2",
    "https://xxx.sharepoint.com/sites/project3")


Start-Transcript -Path "$PSScriptRoot/MoveSites_Log-$((Get-Date).ToString('yyyy-MM-dd-HH-mm')).txt"

try {
    try { 
        $AzureADCommand = Get-AzureADTenantDetail 
    } 
    catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] { 
        Write-Host "Connecting to Azure AD" 
        $AzureConnection = Connect-AzureAD 
    }
    $ProjectsToMove | ForEach-Object {
        .\MoveProjectBetweenHubs.ps1 -SourceHubUrl "https://xxx.sharepoint.com/sites/Prosjektportalen" -DestinationHubUrl "https://xxx.sharepoint.com/sites/Prosjektportalen365" -ProjectUrl $_
    }

    Disconnect-AzureAD
}
catch {
    Write-Host "An error occured: $($_.Exception.Message)"
}
finally {
    Stop-Transcript
}