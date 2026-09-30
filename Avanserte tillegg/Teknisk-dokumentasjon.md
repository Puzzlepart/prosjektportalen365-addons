# Teknisk dokumentasjon – Avanserte tillegg

Dette dokumentet beskriver den tekniske implementasjonen av komponentene i **Avanserte tillegg**, for utviklere og driftspersonell. For en brukerrettet beskrivelse, se [Brukerveiledning.md](Brukerveiledning.md). For installasjon/deployment, se [README.md](README.md).

## Innhold

- [Arkitektur](#arkitektur)
- [Byggeklosser](#byggeklosser)
- [Runbooks (PowerShell)](#runbooks-powershell)
  - [GetSiteInformation](#getsiteinformation)
  - [ArchiveSite](#archivesite)
  - [UpdateProjectDates](#updateprojectdates)
  - [UpdateProjectManager](#updateprojectmanager)
- [Logic Apps (orkestrering)](#logic-apps-orkestrering)
  - [ProjectInfoChanged](#projectinfochanged)
  - [PhaseChanged](#phasechanged)
  - [ChangeArchiveState](#changearchivestate)
  - [RequestProjectAccess](#requestprojectaccess)
- [SharePoint-felter som brukes](#sharepoint-felter-som-brukes)
- [Konfigurasjon](#konfigurasjon)
- [Autentisering og tilganger](#autentisering-og-tilganger)
- [Feilsøking](#feilsøking)

---

## Arkitektur

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Logic Apps    │    │ Azure Automation │    │ SharePoint Online│
│                 │    │                 │    │                 │
│ • PhaseChanged  │───▶│ • ArchiveSite   │───▶│ • Prosjektområder│
│ • ProjectInfo   │    │ • UpdateManager │    │ • Hub-området   │
│   Changed       │    │ • UpdateDates   │    │ • Dokumentbibl. │
│ • ChangeArchive │    │ • GetSiteInfo   │    │                 │
│   State         │    │                 │    │                 │
│ • RequestProject│    │                 │    │                 │
│   Access        │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │ API Connectors  │
                    │                 │
                    │ • SharePointOnline│
                    │ • Automation    │
                    │ • Office365     │
                    └─────────────────┘
```

Alle ressurser provisjoneres via Bicep-maler under [Infrastructure/bicep](Infrastructure/bicep/) og deployes med [Deploy-Solution.ps1](Deploy-Solution.ps1). Automation-kontoen og Logic Apps kjører med **System-Assigned Managed Identity**, som gis rettigheter i SharePoint (App-Only/Sites.FullControl.All via Entra ID-appen som opprettes av [Scripts/createentraidapp.ps1](Scripts/createentraidapp.ps1) og [Scripts/createManagedIdentity.ps1](Scripts/createManagedIdentity.ps1)).

## Byggeklosser

| Type | Antall | Plassering |
| --- | --- | --- |
| PowerShell-runbooks | 4 | `Infrastructure/scripts/*.ps1` (kilde) → inlines til `Infrastructure/bicep/automation/runbooks/*.bicep` ved deploy |
| Logic Apps (workflows) | 4 | `Infrastructure/bicep/logic-apps/*.bicep` |
| API-connectors | 3 (SharePointOnline, Automation, Office365) | `Infrastructure/bicep/connectors/*.bicep` |
| Automation Account | 1 | `Infrastructure/bicep/automation/AutomationAccount.bicep` |

Runbooks kjører **PnP.PowerShell** i en egendefinert runtime-environment (pakket i `bundle/`), og kobler til SharePoint med `Connect-PnPOnline -ManagedIdentity` når de kjører inne i Azure Automation (`$PSPrivateMetadata -ne $null`). Ved lokal testing/kjøring brukes `-UseWebLogin` i stedet.

---

## Runbooks (PowerShell)

### GetSiteInformation

**Fil:** [Infrastructure/scripts/GetSiteInformation.ps1](Infrastructure/scripts/GetSiteInformation.ps1)

Hjelperunbook som andre jobber/Logic Apps kaller synkront (`wait: true`) for å hente metadata om et prosjektområde før de gjør noe med det.

| Parameter | Beskrivelse |
| --- | --- |
| `Url` | URL til prosjektområdet som skal leses |

**Logikk:**

1. Kobler til `Url` med `Connect-PnPOnline`.
2. Henter `Site.GroupId` og `Site.Id` (M365-gruppe / site-ID).
3. Kaller REST-endepunktet `/_api/web/HubSiteData` for å finne `HubSiteUrl`.
4. Leser element med `Id 1` fra listen **Prosjektegenskaper** og henter `Label`-verdien til `GtProjectPhase`.
5. Returnerer et JSON-objekt (`ConvertTo-Json`) med `SiteTitle`, `GroupId`, `SiteId`, `HubSiteUrl`, `Phase`.

Dette JSON-svaret parses av det kallende Logic App-steget (`ParseJson`-action) og brukes videre til å rute til riktig runbook/logic app.

---

### ArchiveSite

**Fil:** [Infrastructure/scripts/ArchiveSite.ps1](Infrastructure/scripts/ArchiveSite.ps1)

Setter et prosjektområde i arkivert (skrivebeskyttet) eller aktiv tilstand. Kalles av `ChangeArchiveState` (manuell/SPFx-trigger) og `PhaseChanged` (automatisk ved faseendring til "Ferdig").

| Parameter | Beskrivelse |
| --- | --- |
| `Url` | Prosjektområdets URL |
| `GroupId` | M365-gruppe-ID knyttet til området (for å arkivere/reaktivere Teams) |
| `HubSiteUrl` | URL til hub-området, brukes for å oppdatere prosjektlisten der |
| `Status` | Ønsket `GtProjectLifecycleStatus`-verdi. Faller tilbake til Automation-variabelen `ArchiveStatusName` (default `"Avsluttet"`) hvis ikke satt |

**Konfigurasjonsvariabler (Azure Automation Variables):**

- `ArchiveStatusName` – navnet på status som betyr "arkivert" (default `Avsluttet`)
- `ArchiveBannerText` – teksten som vises i arkivbanneret

**Logikk (forgrenet på om `Status` matcher arkiveringsstatusen):**

*Ved arkivering (`Status -eq $archiveStatusName` og siden ikke allerede er `ReadOnly`):*

1. `Set-ProjectLifecycleStatus` – skriver `GtProjectLifecycleStatus` på elementet med `Id 1` i **Prosjektegenskaper** i selve prosjektområdet (`SystemUpdate`, ingen versjonering/e-postvarsling).
2. `Set-ProjectLifecycleStatusHubLevel` – finner matchende rad i **Prosjekter**-listen i hub-området (spørring på `GtSiteUrl`) og setter samme status + `GtIsArchived = $true`.
3. `Set-SiteArchivedBanner` – setter opp arkivbanner via en `ApplicationCustomizer`-custom action (SPFx-utvidelse, `ClientSideComponentId` hardkodet i skriptet).
4. `Set-PnPTenantSite -LockState ReadOnly` – låser hele nettstedssamlingen.
5. Arkiverer tilhørende Teams-team via `Set-PnPTeamsTeamArchivedState -Archived:$true` (best effort, fanges i try/catch).

*Ved reaktivering (alle andre tilfeller):*

1. Hvis siden er `ReadOnly`: `Set-PnPTenantSite -LockState Unlock`, deretter en fast `Start-Sleep -Seconds 60` (SharePoint trenger tid på å propagere opplåsingen før videre skriving).
2. Reaktiverer Teams-teamet (`Archived:$false`).
3. Setter tilbake site-eier (`Set-PnPTenantSite -Owners $UserName`) — merk: `$UserName` er ikke deklarert som parameter i skriptet, se [Feilsøking](#feilsøking).
4. Oppdaterer status i både prosjektområdet og hub-listen (samme funksjoner som over).
5. Fjerner arkivbanneret (`Set-SiteArchivedBanner -Disable`).

> **Merk:** Selve tildelingen/fjerningen av den grafiske arkivbanner-custom-actionen er kommentert ut i koden (`#Add-PnPCustomAction` / `#Remove-PnPCustomAction`). Banneret styres i praksis av SPFx-applikasjonen som leser `GtIsArchived`/status-feltet, ikke av en dynamisk provisjonert custom action fra dette skriptet slik det står i dag.

---

### UpdateProjectDates

**Fil:** [Infrastructure/scripts/UpdateProjectDates.ps1](Infrastructure/scripts/UpdateProjectDates.ps1)

Beregner oppfølgingsdatoer basert på overleveringsdato. Trigges av `ProjectInfoChanged` når `GtcHandoverDate` endres.

| Parameter | Beskrivelse |
| --- | --- |
| `Url` | Prosjektområdets URL (påkrevd) |
| `HubSiteUrl` | Hub-områdets URL (påkrevd) |

**Konfigurasjonsvariabel:** `DateCalculationRules` – JSON-streng, default:
```json
{"inspectionPeriodYears":1,"waiverPeriodYears":3,"complaintPeriodYears":5}
```

**Logikk:**

1. Leser `GtcHandoverDate` fra **Prosjektegenskaper** (`Id 1`) på prosjektområdet.
2. Hvis datoen er satt, beregnes:
   - `GtcYearInspectionDate` = HandoverDate + `inspectionPeriodYears`
   - `GtcWaiverDate` = HandoverDate + `waiverPeriodYears`
   - `GtcComplaintDate` = HandoverDate + `complaintPeriodYears`
3. Skriver de tre feltene tilbake til **Prosjektegenskaper** (`SystemUpdate`).
4. Kobler til `HubSiteUrl`, finner matchende rad i **Prosjekter** via `GtSiteUrl`, og speiler de samme tre feltene der.

Hvis `GtcHandoverDate` er tom, gjøres ingen oppdatering (`$Values` forblir `$null`).

---

### UpdateProjectManager

**Fil:** [Infrastructure/scripts/UpdateProjectManager.ps1](Infrastructure/scripts/UpdateProjectManager.ps1)

Setter riktig prosjektleder basert på fase, og styrer tilganger til mapper med sensitivt anskaffelsesinnhold. Trigges av `PhaseChanged` og av `ProjectInfoChanged` (når `GtVeiPlanningManager`, `GtVeiProjectingManager` eller `GtVeiConstructionManager` endres).

| Parameter | Beskrivelse |
| --- | --- |
| `Url` | Prosjektområdets URL (påkrevd) |
| `HubSiteUrl` | Hub-områdets URL (påkrevd) |

**Konfigurasjonsvariabel:** `DefaultManagerRole` – SharePoint-tillatelsesnivå som gis til prosjektleder på de beskyttede mappene (default `"Full Kontroll"`).

**Logikk:**

1. Leser `GtProjectPhase`, `GtVeiPlanningManager` og `GtVeiProjectingManager` fra **Prosjektegenskaper**.
2. Hvis fasens `Label` er **"Planfase"**: velger `GtVeiPlanningManager` som ny `GtProjectManager`. Ellers (alle andre faser): velger `GtVeiProjectingManager`.
3. Kaller `BreakInheritanceAndSetPermissions` med den valgte personens e-post, som for hver av følgende mapper i biblioteket **Dokumenter**:
   - `2 Byggeplanfase/20 Konkuransegrunnlag og kontrahering/Kontrahering`
   - `2 Byggeplanfase/10 Byggeplanlegging/Anskaffelser/Tilbud`
   - `2 Byggeplanfase/10 Byggeplanlegging/Anskaffelser/Kontrakter`
   - `1 Planfase/20 Prosjektledelse/Anskaffelser/Tilbud`
   - `1 Planfase/20 Prosjektledelse/Anskaffelser/Kontrakter`

   sjekker `HasUniqueRoleAssignments` på mappen:
   - **Arv ikke brutt ennå:** `Set-PnPListItemPermission -AddRole $defaultManagerRole -ClearExisting` — bryter arv og gir *kun* prosjektlederen tilgang.
   - **Arv allerede brutt:** samme kall *uten* `-ClearExisting` — legger til prosjektlederen uten å fjerne eksisterende (manuelt tildelte) rettigheter.
4. Skriver `GtProjectManager` til **Prosjektegenskaper**, og speiler feltet til matchende rad i hub-listen **Prosjekter** (samme `GtSiteUrl`-oppslag som de andre runbookene).

---

## Logic Apps (orkestrering)

Alle Logic Apps er definert som Consumption-workflows (`Microsoft.Logic/workflows`) med `SystemAssigned` identity, og starter Automation-jobber via `ApiConnection`-actions mot `azureautomation`-connectoren (`.../jobs`, med `runbookName` i query-string).

### ProjectInfoChanged

**Fil:** [Infrastructure/bicep/logic-apps/ProjectInfoChanged.bicep](Infrastructure/bicep/logic-apps/ProjectInfoChanged.bicep)

- **Trigger:** `ApiConnection`-polling-trigger mot SharePoint (`sharepointonline`-connector), `onchangeditems` på prosjektlisten i hub-området, hvert minutt (`recurrence: 1 Minute`), med `splitOn` slik at hver endret rad kjøres som egen instans.
- **Get_project_changes:** Henter feltendringer (`ColumnHasChanged`) siden forrige versjon (`since: VersionNumber - 1`) for den aktuelle raden.
- **Condition (Manager):** Hvis `GtVeiPlanningManager`, `GtVeiProjectingManager` eller `GtVeiConstructionManager` er endret → starter `UpdateProjectManager`-runbooken (async, `wait: false`).
- **Condition (Date):** Hvis `GtcHandoverDate` er endret → starter `UpdateProjectDates`-runbooken (async).

Parametere som må settes ved deploy: `hubSiteUrl`, `projectListGuid`, `listViewGuid`, `automationAccountName`, samt connector-IDer.

### PhaseChanged

**Fil:** [Infrastructure/bicep/logic-apps/PhaseChanged.bicep](Infrastructure/bicep/logic-apps/PhaseChanged.bicep)

- **Trigger:** HTTP-request-trigger (`When_a_HTTP_request_is_received`), forventer `{ webUrl, apiKey }` i body.
- **Steg:**
  1. `Start_Site_Information_job` (synkron, `wait: true`) → kaller `GetSiteInformation`.
  2. `Get_Site_Information_Output` henter jobb-resultatet.
  3. `Parse_SiteInfo_JSON` parser JSON til `GroupId`, `SiteTitle`, `HubSiteUrl`, `Phase`, `SiteId`.
  4. `Update_Project_Manager_Field` starter alltid `UpdateProjectManager` (async) — dvs. prosjektleder/tilgangsstyring evalueres på *enhver* faseendring, ikke bare til "Ferdig".
  5. `If_phase_is_Finished`: sammenligner `Phase` med parameteren `finishedPhaseText` (default `"Ferdig"`). Hvis lik → starter `ArchiveSite` (async) med `Status` implisitt satt til arkiveringsstatus via runbookens egen default/Automation-variabel.

> Merk at selve HTTP-triggeren i dette Logic App-et ikke er koblet til noe kall i denne kodebasen (den forventes kalt fra det underliggende Prosjektportalen-produktet/kjernen når `GtProjectPhase` endres — ikke en del av dette add-on-repoet).

### ChangeArchiveState

**Fil:** [Infrastructure/bicep/logic-apps/ChangeArchiveState.bicep](Infrastructure/bicep/logic-apps/ChangeArchiveState.bicep)

- **Trigger:** HTTP-request, forventer `{ Url, Status }`.
- **Steg:** Kjører `GetSiteInformation` (synkront) for å hente `GroupId`/`HubSiteUrl`, parser resultatet (`Parse_JSON`), og starter deretter `ArchiveSite` (async) med `URL`, `groupID`, `status` og `HubSiteUrl` fra forespørselen/parsingen.
- Dette er endepunktet som kalles av **"Sett prosjekt som aktivt"**-knappen i SPFx-utvidelsen (i kjerneproduktet Prosjektportalen365, ikke i dette repoet) med `Status` satt til den aktive livssyklusstatusen. Samme endepunkt kan i prinsippet også trigge arkivering manuelt ved å sende arkiveringsstatusen.

### RequestProjectAccess

**Fil:** [Infrastructure/bicep/logic-apps/RequestProjectAccess.bicep](Infrastructure/bicep/logic-apps/RequestProjectAccess.bicep)

Den eneste manuelle/brukerinitierte flyten, og den mest omfattende. Kalles fra en Dynamisk liste-webpart med valgte prosjektrader.

- **Trigger:** HTTP POST med `listName`, `listId`, `webUrl`, `siteId`, `selectedItems[]` (fullt skjema av prosjektlistekolonner), `currentUser { displayName, email, loginName }`.
- **Flyt:**
  1. `Get_Users_(HTTP)` henter `_api/web/siteusers` fra hub-området, `Build_Users_array` reduserer til `{ID, Title, Email}`.
  2. `Iterate_Projects` (foreach valgt prosjekt): slår opp `GtProjectManagerId` og `GtProjectOwnerId` mot brukerlisten, og bygger en `ProjectArray`-variabel med prosjektnavn, URL, samt e-post/navn for eier og prosjektleder.
  3. `For_the_Project` (foreach rad i `ProjectArray`):
     - Bygger en `approvers`-liste (eier og/eller prosjektleder, hvis e-post finnes).
     - `Send_approval_email_one_project`: sender **godkjenningsepost** via Office 365-connectoren (`ApiConnectionWebhook`, `/approvalmail/$subscriptions`) til `approvers`, med knappene **"Godkjenn"/"Avslå"** (`Options: 'Godkjenn,Avslå'`).
     - `If_Approved`: hvis godkjent:
       - `Get_Visitor_group`: henter sidens `AssociatedVisitorGroup` via REST.
       - `Ensure_user`: sikrer at brukeren (`currentUser`) finnes som SharePoint-bruker på prosjektområdet.
       - `Add_user_to_visitor_group`: legger brukeren til i besøksgruppen (`sitegroups(id)/users`), dvs. gir lesetilgang til prosjektområdet.
- Alle SharePoint-kall mot det enkelte prosjektområdet gjøres med SharePoint-connectorens generiske `httprequest`-dataset (`/datasets/{webUrl}/httprequest`), ikke med en fast connection-URL — det gjør at samme Logic App kan nå ethvert prosjektområde i tenanten.

---

## SharePoint-felter som brukes

| Felt | Liste | Brukes av |
| --- | --- | --- |
| `GtProjectPhase` | Prosjektegenskaper | GetSiteInformation, UpdateProjectManager, PhaseChanged (fase-tekst) |
| `GtProjectLifecycleStatus` | Prosjektegenskaper, Prosjekter (hub) | ArchiveSite |
| `GtIsArchived` | Prosjekter (hub) | ArchiveSite |
| `GtcHandoverDate` | Prosjektegenskaper | UpdateProjectDates (kilde), ProjectInfoChanged (trigger) |
| `GtcYearInspectionDate`, `GtcWaiverDate`, `GtcComplaintDate` | Prosjektegenskaper, Prosjekter (hub) | UpdateProjectDates (mål) |
| `GtVeiPlanningManager`, `GtVeiProjectingManager`, `GtVeiConstructionManager` | Prosjektegenskaper | UpdateProjectManager (kilde), ProjectInfoChanged (trigger) |
| `GtProjectManager` | Prosjektegenskaper, Prosjekter (hub) | UpdateProjectManager (mål) |
| `GtSiteUrl` | Prosjekter (hub) | Alle runbooks, for å finne raden i hub-listen som tilsvarer prosjektområdet |
| `GtProjectManagerId`, `GtProjectOwnerId` | Prosjekter (hub) | RequestProjectAccess (finne godkjennere) |

---

## Konfigurasjon

Konfigurasjon skjer på to nivåer:

1. **Deploy-tid** – JSON-filer i [config/](config/) (`config.json`, `runbooks.json`, `logic-apps.json`, osv.) styrer hvilke komponenter som deployes og med hvilke bicep-parametere (f.eks. `finishedPhaseText`, `hubSiteUrl`, `projectListGuid`).
2. **Kjøretid** – Verdier lagres som **Azure Automation Variables** på Automation-kontoen og leses av runbooks via `Get-AutomationVariable` (med hardkodet fallback-verdi i skriptet hvis variabelen mangler eller koden kjører utenfor Automation-kontekst):

| Automation-variabel | Brukes i | Default |
| --- | --- | --- |
| `ArchiveStatusName` | ArchiveSite | `Avsluttet` |
| `ArchiveBannerText` | ArchiveSite | `Dette området er arkivert og skrivebeskyttet...` |
| `DateCalculationRules` (JSON) | UpdateProjectDates | `{"inspectionPeriodYears":1,"waiverPeriodYears":3,"complaintPeriodYears":5}` |
| `DefaultManagerRole` | UpdateProjectManager | `Full Kontroll` |

Å endre disse variablene i Azure Automation krever ingen redeploy av runbooks.

---

## Autentisering og tilganger

- Automation-kontoen og alle Logic Apps kjører med **System-Assigned Managed Identity**.
- Runbooks kobler til SharePoint med `Connect-PnPOnline -Url <site> -ManagedIdentity` når `$PSPrivateMetadata` finnes (dvs. når de faktisk kjører i Azure Automation).
- Identiteten må ha tilstrekkelige rettigheter i SharePoint (Sites.FullControl.All / Entra ID app-registrering, se [Scripts/createentraidapp.ps1](Scripts/createentraidapp.ps1) og [Scripts/createManagedIdentity.ps1](Scripts/createManagedIdentity.ps1)) samt Teams-administrasjon for arkivering/reaktivering av team.
- `SharePointOnline`-API-connectoren (brukt av `ProjectInfoChanged` og `RequestProjectAccess`) må autoriseres manuelt mot en tjenestekonto etter deploy (se [README.md](README.md#authorize-sharepoint-connector)) — dette er en delegert (bruker-)kobling, ikke managed identity.
- `Office365`-connectoren (brukt av `RequestProjectAccess` for godkjenningseposter) krever tilsvarende autorisasjon av en avsenderkonto.

---

## Feilsøking

- **Jobber feiler stille:** De fleste runbook-kall fra Logic Apps kjøres med `wait: false` (async/fire-and-forget). Sjekk jobbhistorikk under Automation-kontoen → "Jobs" for faktisk feilmelding, ikke bare Logic App-kjøringen.
- **`ArchiveSite` feiler ved reaktivering med "Owners not found" e.l.:** Skriptet refererer til `$UserName` uten at denne er deklarert som `param()` i [ArchiveSite.ps1](Infrastructure/scripts/ArchiveSite.ps1) — verdien vil være `$null` med mindre den settes globalt et annet sted i kjøremiljøet. Vurder å legge til `$UserName` som runbook-parameter hvis reaktivert eierskap er nødvendig.
- **Fast 60-sekunders pause ved opplåsing:** `ArchiveSite.ps1` venter `Start-Sleep -Seconds 60` etter `Set-PnPTenantSite -LockState Unlock` for å gi SharePoint tid til å propagere endringen før øvrige skriveoperasjoner. Kortere ventetid kan gi "Access denied"-feil på påfølgende steg.
- **Prosjektleder/dato ikke oppdatert:** Sjekk at riktig rad finnes i **Prosjekter**-listen i hub-området med `GtSiteUrl` som eksakt match mot prosjektområdets URL — alle runbooks er avhengige av dette oppslaget for å speile data til hub-nivå.
- **`ProjectInfoChanged` trigges ikke:** Triggeren er en pollende `onchangeditems`-spørring (hvert minutt) mot en spesifikk `listViewGuid`. Kontroller at visningen som er konfigurert i bicep-parameteren faktisk inneholder de overvåkede kolonnene, og at endringen er eldre enn ett minutt før du feilsøker videre.
- **Se også** [Brukerveiledning.md](Brukerveiledning.md) for beskrivelse av brukeropplevd atferd, og [Infrastructure/deployment/Validate-Solution.ps1](Infrastructure/deployment/Validate-Solution.ps1) / [Validate-Prerequisites.ps1](Validate-Prerequisites.ps1) for validering av en deployert løsning.
