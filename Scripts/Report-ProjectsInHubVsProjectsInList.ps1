Param(
    [string]$PortfolioUrl = "https://innlandet.sharepoint.com/sites/prosjektportalen",
    [string]$ClientId = "da6c31a6-b557-4ac3-9994-7315da06ea3a"
)
$ErrorActionPreference = "Stop"

[System.Uri]$Uri = $PortfolioUrl
$AdminSiteUrl = (@($Uri.Scheme, "://", $Uri.Authority) -join "").Replace(".sharepoint.com", "-admin.sharepoint.com")

Connect-PnPOnline -Url $AdminSiteUrl -ClientId $ClientId -ErrorAction Stop -WarningAction Ignore

Write-Host "Retrieving all sites of the Project Portal hub..."
$ProjectsInHub = Get-PnPHubSiteChild -Identity $PortfolioUrl

Connect-PnPOnline -Url $PortfolioUrl -Interactive -ClientId $ClientId -ErrorAction Stop -WarningAction Ignore
$ProjectsInList = Get-PnPListItem -List "Prosjekter"
$ProjectsInListUrls = $ProjectsInList | ForEach-Object { $_["GtSiteUrl"] } | Where-Object { $_ -ne $null }

$differences = Compare-Object -ReferenceObject $ProjectsInHub -DifferenceObject $ProjectsInListUrls

if ($differences.Count -eq 0) {
    Write-Host "All project sites in the hub are present in the project list, and vice versa." -ForegroundColor Green
    return
}
$differences | ForEach-Object {
    if ($_.SideIndicator -eq "<=") {
        Write-Host "`tProject site in hub but NOT in list: $($_.InputObject)" -ForegroundColor Yellow
    } else {
        Write-Host "`tProject site in list but NOT in hub: $($_.InputObject)" -ForegroundColor Magenta
    }
}