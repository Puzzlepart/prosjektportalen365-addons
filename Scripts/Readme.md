# Skript for Prosjektportalen 365

Dette er en samling av skript for PP365 som er delt som add-ons - altså ikke en del av hovedløsningen. Skriptene er beskrevet under. Brukes på eget ansvar, vi anbefaler å sette seg inn i hva skriptene gjør før de kjøres.

## MoveProjectBetweenHubs.ps1

MoveProjectBetweenHubs er et skript for å flytte et prosjektområde fra en hub til en annen. Dette kan være aktuelt dersom et prosjekt skal flyttes fra en portefølje til en annen, for eksempel fra aktive prosjekter til en egen arkiv-portefølje.

I sin enkleste form kan jo dette gjøres ved å endre hub-tilknytning rett fra prosjektområdet. Dette vil derimot ikke ivareta prosjektegenskaper, statusrapporter og (etterhvert) tidslinje-elementer, som lagres på porteføljeområdet. Skriptet sørger for at disse dataene også følger med til porteføljen man flytter til.

Skriptet må kjøres som SharePoint administrator. Skriptet antar også at brukeren som kjører skriptet er eier på kildeporteføljen og målporteføljen. Skriptet antar at du har lastet inn PnP.PowerShell fra før.

### Eksempel

``
.\MoveProjectBetweenHubs.ps1 -SourceHubUrl "https://tenant.sharepoint.com/sites/pp" -DestinationHubUrl "https://tenant.sharepoint.com/sites/pparkiv" -ProjectUrl "https://tenant.sharepoint.com/sites/mittprosjekt"
``
