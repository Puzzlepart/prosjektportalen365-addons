# Forskningsmal for Prosjektportalen 365

Forskningsmalen (FoU) for Prosjektportalen er en samling felter, lister, webdeler og tillegg som sammen utgjør en mal for forskningsprosjekter. Forskningsmalen er blitt utarbeidet i samarbeid med Høgskolen i Innlandet, og Puzzlepart har satt opp dette som mal for deling på GitHub. Videre forvaltning vil gjøres primært av Puzzlepart, og vi ønsker innspill på innholdet i malen. For spørsmål og innspill, logg gjerne en issue i dette området på GitHub eller send oss en e-post på <prosjektportalen@puzzlepart.com>.

Forskningsmalen installeres som tillegg til Prosjektportalen 365. Ved å installere forskningsmalen vil man få følgende satt opp i porteføljeområdet

1. Et nytt prosjekttillegg, `Forskningsmal`
2. Fire nye lister i forskningsprosjektet, `Etiske vurderinger`, `Prosjektorganisasjon`, `Work Breakdown Structure` og `Publiseringer`
3. En ny aggregert webdel, `Publiseringer` som viser aggregert informasjon om publiseringer registrert i prosjekter.

## Installasjon

Forutsetninger:

- Du har installert Prosjektportalen 365 på et område

Denne pakken kommer ikke bundlet med PnP.PowerShell. Vi anbefaler sterkt å installere med samme versjon som kommer med Prosjektportalen 365, som per 23.09.2024 er PnP.PowerShell 2.12.0.

1. Last ned release-pakken fra releases og pakk ut pakken lokalt.
2. Kjør kommandoer under for å installere oppsettet.
3. Du kan nå opprette nye prosjekter og velge malen som heter `Forskning`.

### Manuelle steg etter installasjon

- Legge til `Publiseringer` side i toppmenyen
- Knytte opp prosjekttilllegget til malen samt listeinnhold
- Legge til prosjektinnholdskolonnene til den nye datakilden
- Legge til nye `Prosjektkolonner` til visning samt filtrering
- Legge til nytt sitescript i sitedesign

Eksempel:

```pwsh
# Legge på tilpasninger til Prosjektportalen

Connect-PnPOnline "Url til prosjektportalen" -Interactive -ClientId da6c31a6-b557-4ac3-9994-7315da06ea3a
Invoke-PnPSiteTemplate -Path ./xx.xml
```

```pwsh
# Opprette SiteScript for Publiseringelement
$Content = (Get-Content -Path "./SiteScripts/Publiseringelement.txt" -Raw | Out-String)
$SiteScript = Add-PnPSiteScript -Title "Innholdstype - Publiseringelement" -Content $Content
```

```pwsh
# Update sitedesign for Prosjektportalen with the new contenttype (Main channel)
# Pre-requisite: SiteScripts for the new contenttype must be created beforehand

$SiteDesignName = "Prosjektomr%C3%A5de"

$SiteDesignName = [Uri]::UnescapeDataString($SiteDesignName)
$SiteDesignDesc = [Uri]::UnescapeDataString("Samarbeid i et prosjektomr%C3%A5de fra Prosjektportalen")
$SiteDesignThumbnail = "https://publiccdn.sharepointonline.com/prosjektportalen.sharepoint.com/sites/ppassets/Thumbnails/prosjektomrade.png"

$SiteScriptIds = @()

$SiteScripts = Get-PnPSiteScript | Where-Object { $_.Title -notlike "* - Test" }
foreach ($SiteScript in $SiteScripts) {
  $SiteScriptIds += $SiteScript.Id.Guid
}

$SiteDesign = Get-PnPSiteDesign -Identity $SiteDesignName
$SiteDesign = Set-PnPSiteDesign -Identity $SiteDesign -SiteScriptIds $SiteScriptIds -Description $SiteDesignDesc -Version "1" -ThumbnailUrl $SiteDesignThumbnail
```

```pwsh
# Update sitedesign for Prosjektportalen with the new contenttype (Test channel)
# Pre-requisite: SiteScripts for the new contenttype must be created beforehand

$SiteDesignName = "Prosjektomr%C3%A5de [test]"
$SiteDesignName = [Uri]::UnescapeDataString($SiteDesignName)
$SiteDesignDesc = [Uri]::UnescapeDataString("Denne malen brukes n%C3%A5r det opprettes prosjekter under en test-kanal installasjon av Prosjektportalen")
$SiteDesignThumbnail = "https://publiccdn.sharepointonline.com/prosjektportalen.sharepoint.com/sites/ppassets/Thumbnails/prosjektomrade-test.png"

$SiteScriptIds = @()
$SiteScripts = Get-PnPSiteScript | Where-Object { $_.Title -like "* - Test" -or $_.Title -like "*Publiseringelement*" }

foreach ($SiteScript in $SiteScripts) {
  $SiteScriptIds += $SiteScript.Id.Guid
}

$SiteDesign = Get-PnPSiteDesign -Identity $SiteDesignName
$SiteDesign = Set-PnPSiteDesign -Identity $SiteDesign -SiteScriptIds $SiteScriptIds -Description $SiteDesignDesc -Version "1" -ThumbnailUrl $SiteDesignThumbnail
```

TODO: Lage installasjonsscript for å gjøre dette enklere. Samt utføre de manuelle operasjonene.
