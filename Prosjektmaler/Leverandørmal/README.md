# Leverandørmal for Prosjektportalen 365

[![version](https://img.shields.io/badge/version-1.0.0-green.svg)](https://semver.org)

Veimodulen for Prosjektportalen er en samling komponenter som sammen utgjør en mal for veiprosjekter. Veimodulen er blitt utarbeidet av Rogaland fylkeskommune, og Puzzlepart har bistått i å ekstrahere tilpasningene som mal for deling på GitHub. Videre forvaltning vil gjøres primært av Puzzlepart, og vi ønsker innspill på innholdet i malen. For spørsmål og innspill, logg gjerne en issue i dette området på GitHub eller send oss en e-post på <prosjektportalen@puzzlepart.com>.

Veimodulen installeres som et tillegg til Prosjektportalen 365. Ved å installere veimodulen vil man få følgende satt opp i porteføljeområdet

1. En ny prosjektmal `Veiprosjekt` som man kan bruke som mal for nye prosjekter
2. En ny fasesjekkliste `Fasesjekkliste Vei` med egne fasesjekkpunkter for veiprosjekter. Fasesjekklisten har også ny kolonne `Forankret i` for å indikere hvor fasesjekkpunktet er forankret
3. En ny liste for planneroppgaver `Planneroppgaver Vei` med egne oppgaver for veiprosjekter
4. Et nytt dokumentbibliotek `Standarddokumenter Vei` med egen folderstruktur som følger fasene
5. Fasene i veiprosjekter er `Planlegge`, `Prosjektere`, `Bygge` og `Avslutte`
6. Dokumentbiblioteket i veiprosjekter har fått to nye kolonner `Fag` og `Emne` (taksonomi)
7. Nye prosjektegenskaper i veiprosjekter for ansvar i fasene

## Installasjon

Forutsetninger:

- Du har installert Prosjektportalen 365 på et område
- Du er Term Store Administrator (pga. nye termer)
- Du er SharePoint Administrator (pga. søkekonfigurasjon)

Denne pakken kommer ikke bundlet med PnP.PowerShell. Vi anbefaler sterkt å installere med samme versjon som kommer med Prosjektportalen 365, som per 21.12.2023 er PnP.PowerShell 1.11.0.

1. Last ned release-pakken fra releases og pakk ut pakken lokalt
2. Kjør Install.ps1 med -Url parameter til din Prosjektportalen-installasjon (PP365 må være installert på forhånd)
3. Du kan nå opprette nye prosjekter og velge malen som heter `Veiprosjekt`

Eksempel:

```pwsh
.\Install.ps1 -Url https://puzzlepart.sharepoint.com/sites/ppveimodul
```
