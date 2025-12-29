<#
.SYNOPSIS
Builds a release package for Prosjektportalen 365 Forskningsmal

.DESCRIPTION
Builds a release package for Prosjektportalen 365 Forskningsmal. The release package contains all files needed to install Prosjektportalen 365 Forskningsmal in a PP365 installation.
#>

#region Paths
$START_PATH = Get-Location
$ROOT_PATH = "$PSScriptRoot"
$PNP_TEMPLATES_BASEPATH = "$ROOT_PATH/Template"
$GIT_HASH = git log --pretty=format:'%h' -n 1

$PACKAGE_JSON = Get-Content "$ROOT_PATH/package.json" | ConvertFrom-Json
$VERSION = $PACKAGE_JSON.version
$RELEASE_NAME = "pp365-forskningsmal-$VERSION.$($GIT_HASH)"
$RELEASE_PATH = "$ROOT_PATH/release/$RELEASE_NAME"
#endregion

Write-Host "[Building release $RELEASE_NAME]" -ForegroundColor Cyan

$RELEASE_FOLDER = New-Item -Path "$RELEASE_PATH" -ItemType Directory -Force
$RELEASE_PATH = $RELEASE_FOLDER.FullName

$RELEASE_PATH_TEMPLATES = (New-Item -Path "$RELEASE_PATH/Templates" -ItemType Directory -Force).FullName
$RELEASE_PATH_SITESCRIPTS = (New-Item -Path "$RELEASE_PATH/SiteScripts" -ItemType Directory -Force).FullName
$RELEASE_PATH_SCRIPTS = (New-Item -Path "$RELEASE_PATH/Scripts" -ItemType Directory -Force).FullName


Set-Location $PSScriptRoot
Convert-PnPFolderToSiteTemplate -Out "$RELEASE_PATH_TEMPLATES/Forskningsmal.pnp" -Folder $PNP_TEMPLATES_BASEPATH -Force

Copy-Item -Path "$PSScriptRoot/SiteScripts/*" -Destination $RELEASE_PATH_SITESCRIPTS -Force
Copy-Item -Path "$PSScriptRoot/Scripts/*" -Destination $RELEASE_PATH_SCRIPTS -Force
Copy-Item -Path "$PSScriptRoot/Install.ps1" -Destination $RELEASE_PATH -Force
$resourceFiles = Get-ChildItem -Path "$PSScriptRoot/Template" -Filter "*.resx" -File
foreach ($file in $resourceFiles) {
    Copy-Item -Path $file.FullName -Destination $RELEASE_PATH -Force
}

Remove-Item -Path "$($RELEASE_PATH).zip" -Force -ErrorAction SilentlyContinue

Add-Type -Assembly "System.IO.Compression.FileSystem"
[IO.Compression.ZipFile]::CreateFromDirectory($RELEASE_PATH, "$($RELEASE_PATH).zip")  
Write-Host "Done building release $RELEASE_NAME" -ForegroundColor Green
Set-Location $START_PATH