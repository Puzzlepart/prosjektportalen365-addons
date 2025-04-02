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
2. Kjør Install.ps1 med URL mot hub-området for å installere oppsettet.
3. Du kan nå opprette nye prosjekter og velge malen som heter `Forskning`.

### Manuelle steg etter installasjon

- Legg til lenke til  `SitePages/Publiseringer.aspx` siden i toppmenyen
- Legg til prosjektinnholdskolonnene til den nye datakilden `Alle publiseringer`
- Legg til nye `Prosjektkolonner` til visningen `Alle publiseringer` samt filtreringskolonner
