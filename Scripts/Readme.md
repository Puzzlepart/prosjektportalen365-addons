# Skript for Prosjektportalen 365

Dette er en samling av skript for PP365 som er delt som add-ons - altså ikke en del av hovedløsningen. Skriptene er beskrevet under. Brukes på eget ansvar, vi anbefaler å sette seg inn i hva skriptene gjør før de kjøres.

## MoveProjectBetweenHubs.ps1

MoveProjectBetweenHubs er et skript for å flytte et prosjektområde fra en hub til en annen. Dette kan være aktuelt dersom et prosjekt skal flyttes fra en portefølje til en annen, for eksempel fra aktive prosjekter til en egen arkiv-portefølje.

I sin enkleste form kan jo dette gjøres ved å endre hub-tilknytning rett fra prosjektområdet. Dette vil derimot ikke ivareta prosjektegenskaper, statusrapporter og tidslinje-elementer, som lagres på porteføljeområdet. Skriptet sørger for at disse dataene også følger med til porteføljen man flytter til.

Skriptet må kjøres som SharePoint administrator. Skriptet antar også at brukeren som kjører skriptet er eier på kildeporteføljen og målporteføljen. Skriptet antar at du har lastet inn PnP.PowerShell fra før. Skriptet er oppdatert og støtter PnP.PowerShell 2.2.0.

### Eksempel

``
.\MoveProjectBetweenHubs.ps1 -SourceHubUrl "https://tenant.sharepoint.com/sites/pp" -DestinationHubUrl "https://tenant.sharepoint.com/sites/pparkiv" -ProjectUrl "https://tenant.sharepoint.com/sites/mittprosjekt"
``

## MoveMultipleProjects.ps1

En enkel wrapper på forrige skript for å flytte flere prosjekter, som også transkriberer resultatene til fil.

### Eksempel

``
.\MoveMultipleProjects.ps1 -SourceHubUrl "https://tenant.sharepoint.com/sites/pp" -DestinationHubUrl "https://tenant.sharepoint.com/sites/pparkiv" -ProjectsToMove @("https://tenant.sharepoint.com/sites/mittprosjekt","https://tenant.sharepoint.com/sites/dittprosjekt","https://tenant.sharepoint.com/sites/hennesprosjekt")
``

## GenerateProjectContentWithAI.ps1

Bruker Open AI til å generere innhold i et prosjekt. Fyller ut de vanlige listene med generert innhold. Nyttig for å teste ut Prosjektportalen med relativt realistisk data.

Skriptet henter ut tittel på området, går gjennom de ulike listene, henter ut feltene som skal fylles med data, genererer en prompt basert på dette som returneres som JSON, skriptet behandler innsendt JSON, konverterer hvert elements data til en hashtabell som sendes inn med Add-PnPListItem sin -Values parameter.

Skriptet har følgende forutsetninger
- Du har installert PnP.PowerShell-modulen
- Du har tilgang på/satt opp en Azure Open AI instans og har en deployment med api-nøkkel, baseurl og navn

### Eksempel

````PowerShell
.\GenerateProjectContentWithAI.ps1 -Url "https://prosjektportalen.sharepoint.com/sites/DigitalTransformasjon" -api_key "112233445566778899abc" -api_base "https://company-testing-oaiservice-swedencentral.openai.azure.com/" -model_name "gpt-4-1106-preview"
````