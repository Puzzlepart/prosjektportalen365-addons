# Leverandørmal for Prosjektportalen 365

Leverandørmalen for Prosjektportalen er en samling felter, webdeler og tillegg som sammen utgjør en mal for leverdørprosjekter. Leverandørmalen er blitt utarbeidet i samarbeid med Stord kommune, og Puzzlepart har satt opp dette som mal for deling på GitHub. Videre forvaltning vil gjøres primært av Puzzlepart, og vi ønsker innspill på innholdet i malen. For spørsmål og innspill, logg gjerne en issue i dette området på GitHub eller send oss en e-post på <prosjektportalen@puzzlepart.com>.

Leverandørmalen installeres som tillegg til Prosjektportalen 365. Ved å installere leverandørmalen vil man få følgende satt opp i porteføljeområdet

1. To nye prosjekttillegg, `Leverandørmal` og `Overordnet-leverandørmal`
2. En ny liste `Prosjektsikkerhetslogg` med egne kolonner
3. En ny webdel for overordnede prosjekter, `Sikkerhetsloggelementer for underområder` som viser aggregert sikkerhetslogg for underområder.

## Installasjon

Forutsetninger:

- Du har installert Prosjektportalen 365 på et område

Denne pakken kommer ikke bundlet med PnP.PowerShell. Vi anbefaler sterkt å installere med samme versjon som kommer med Prosjektportalen 365, som per 23.09.2024 er PnP.PowerShell 2.12.0.

1. Last ned release-pakken fra releases og pakk ut pakken lokalt.
2. Kjør Install.ps1 med Url til hubområdet for å installere oppsettet.
3. Du kan nå opprette nye prosjekter og velge malen som heter `Leverandørmal`.
4. Ny aggregert oversikt på portefølje, `Sikkerhetslogg`.
6. Knytte opp de nye Prosjektinnholdskolonnene til de nye datakildene.
7. Legg til `Sikkerhetslogg` aggregert oversikt lenke i navigasjonsmenyen på porteføljeområdet.

