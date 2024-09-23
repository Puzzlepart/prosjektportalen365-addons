# Leverandørmal for Prosjektportalen 365

Leverandørmalen for Prosjektportalen er en samling felter, webdeler og tillegg som sammen utgjør en mal for leverdørprosjekter. Leverandørmalen er blitt utarbeidet i samarbeid med Stord kommune, og Puzzlepart har satt opp dette som mal for deling på GitHub. Videre forvaltning vil gjøres primært av Puzzlepart, og vi ønsker innspill på innholdet i malen. For spørsmål og innspill, logg gjerne en issue i dette området på GitHub eller send oss en e-post på <prosjektportalen@puzzlepart.com>.

Leverandørmalen installeres som tillegg til Prosjektportalen 365. Ved å installere leverandørmalen vil man få følgende satt opp i porteføljeområdet

1. To nye prosjekttillegg, `Leverandørmal` og `Overordnet-leverandørmal`
2. En ny liste `Prosjektsikkerhetslogg` med egne kolonner
3. En ny webdel for overordnede prosjekter, `Sikkerhetsloggelementer for underområder` som viser aggregert sikkerhetslogg for underområder.

## Installasjon

Forutsetninger:

- Du har installert Prosjektportalen 365 på et område

Denne pakken kommer ikke bundlet med PnP.PowerShell. Vi anbefaler sterkt å installere med samme versjon som kommer med Prosjektportalen 365, som per 23.09.2024 er PnP.PowerShell 1.12.0.

1. Last ned release-pakken fra releases og pakk ut pakken lokalt
2. Kjør kommandoer under for å installere oppsettet
3. Du kan nå opprette nye prosjekter og velge malen som heter `Leverandørmal`
4. Ny aggregert oversikt på portefølje, `Sikkerhetslogg`
5. Knytte opp de nye prosjekttilleggene til de nye malene.
6. Knytte opp de nye Prosjektinnholdskolonnene til de nye datakildene

```pwsh

Eksempel:

```pwsh
Connect-PnPOnline "Url til prosjektportalen" -Interactive -ClientId da6c31a6-b557-4ac3-9994-7315da06ea3a
Invoke-PnPSiteTemplate -Path ./xx.xml

# Update sitedesign for Prosjektportalen with the new contenttype
$SiteDesignName = "Prosjektomr%C3%A5de"

$SiteDesignName = [Uri]::UnescapeDataString($SiteDesignName)
$SiteDesignDesc = [Uri]::UnescapeDataString("Samarbeid i et prosjektomr%C3%A5de fra Prosjektportalen")
$SiteDesignThumbnail = "https://publiccdn.sharepointonline.com/prosjektportalen.sharepoint.com/sites/ppassets/Thumbnails/prosjektomrade.png"

$SiteScriptIds = @()

$SiteScripts = Get-PnPSiteScript
foreach ($SiteScript in $SiteScripts) {
    $SiteScriptIds += $SiteScript.Id.Guid
}

$Content = (Get-Content -Path "./SiteScripts/Prosjektsikkerhetsloggelement.txt" -Raw | Out-String)
$SiteScript = Add-PnPSiteScript -Title "Innholdstype - Prosjektsikkerhetslogg" -Content $Content

Get-PnPSiteScript

$SiteDesign = Get-PnPSiteDesign -Identity $SiteDesignName
$SiteDesign = Set-PnPSiteDesign -Identity $SiteDesign -SiteScriptIds $SiteScriptIds -Description $SiteDesignDesc -Version "1" -ThumbnailUrl $SiteDesignThumbnail
```

TODO: Lage installasjonsscript for å gjøre dette enklere. Samt utføre de manuelle operasjonene.
