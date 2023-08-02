Param(
    [Parameter(Mandatory = $true)][string]$SourceHubUrl,
    [Parameter(Mandatory = $true)][string]$DestinationHubUrl,
    [Parameter(Mandatory = $true)][string[]]$ProjectsToMove
)

Start-Transcript -Path "$PSScriptRoot/MoveSites_Log-$((Get-Date).ToString('yyyy-MM-dd-HH-mm')).txt"

try {
    $ProjectsToMove | ForEach-Object {
        .\MoveProjectBetweenHubs.ps1 -SourceHubUrl $SourceHubUrl -DestinationHubUrl $DestinationHubUrl -ProjectUrl $_
    }
}
catch {
    Write-Host "An error occured: $($_.Exception.Message)"
}
finally {
    Stop-Transcript
}