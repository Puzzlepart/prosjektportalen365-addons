# Prosjektdokumentgenerering

Disse skriptene genererer dokumenter fra maler ved å erstatte tokens med data fra SharePoint-lister. Støtter både PowerPoint (`.pptx`) og Word (`.docx`) maler.

## Skript

| Skript | Format | Beskrivelse |
|--------|--------|-------------|
| `run-pptx.ps1` | PowerPoint | Genererer `.pptx`-filer fra PowerPoint-maler |
| `run-docx.ps1` | Word | Genererer `.docx`-filer fra Word-maler |

Begge skriptene bruker samme token-syntaks og støtter samme SharePoint-felttyper.

## Hvordan det fungerer

Skriptet laster ned en mal (`.pptx` eller `.docx`), finner tokens i formatet `{{TokenNavn}}`, erstatter dem med data fra SharePoint-lister, og genererer et nytt dokument.

## Token-syntaks

### Grunnleggende tokens

#### Today-token
Erstattes med dagens dato i norsk format (dd.MM.yyyy).

```
{{Today}}
```

**Eksempel output:** `16.12.2025`

### Liste-tokens

Henter data fra SharePoint-lister og setter dem inn som tekst eller tabeller.

#### Enkel liste (enkelt felt)
Returnerer en ren tekstliste med hver verdi på en ny linje.

```
{{List:ListeNavn;Fields:FeltNavn}}
```

**Eksempel:**
```
{{List:Prosjektleveranser;Fields:Title}}
```

#### Tabell (flere felt)
Returnerer en formatert tabell med overskrifter og datarader. Som standard spenner tabeller over 95% av tilgjengelig bredde (lysbildebredde for PPTX, sidebredde minus marger for DOCX) med like kolonnebredder.

```
{{List:ListeNavn;Fields:Felt1,Felt2,Felt3}}
```

**Eksempel:**
```
{{List:Usikkerhet;Fields:ID,Title,GtRiskDescription,GtRiskStatus}}
```

## Avansert tabellkonfigurasjon

### Egendefinerte kolonnebredder

Spesifiser proporsjonal bredde for hver kolonne ved å bruke parenteser. Verdiene skal være desimaltall som summerer til 1.0 (som representerer 100% av tabellbredden).

```
{{List:ListeNavn;Fields:Felt1(bredde),Felt2(bredde),Felt3(bredde)}}
```

**Eksempel:**
```
{{List:Usikkerhet;Fields:ID(0.1),Title(0.2),GtRiskDescription(0.2),GtRiskConsequence(0.1),GtRiskProbability(0.1),GtRiskStatus(0.1),GtRiskAction(0.2)}}
```

Dette lager en tabell hvor:
- ID-kolonnen tar 10% av tabellbredden
- Title-kolonnen tar 20% av tabellbredden
- GtRiskDescription-kolonnen tar 20% av tabellbredden
- GtRiskConsequence-kolonnen tar 10% av tabellbredden
- GtRiskProbability-kolonnen tar 10% av tabellbredden
- GtRiskStatus-kolonnen tar 10% av tabellbredden
- GtRiskAction-kolonnen tar 20% av tabellbredden

**Merk:** Du kan bruke enten punktum (`.`) eller komma (`,`) som desimalskilletegn: `0.1` eller `0,1`

Hvis breddene ikke summerer til nøyaktig 1.0, vil de automatisk normaliseres med en advarsel.

### Egendefinert tabellbredde

Som standard spenner tabeller over 95% av tilgjengelig bredde. Du kan tilpasse dette ved å bruke `Width`-parameteren.

```
{{List:ListeNavn;Fields:Felt1,Felt2,Felt3;Width:forhold}}
```

**Eksempel (70% av tilgjengelig bredde):**
```
{{List:Prosjektleveranser;Fields:ID(0.1),Title(0.2),GtDeliveryDescription(0.7);Width:0.7}}
```

**Eksempel (50% av tilgjengelig bredde):**
```
{{List:Nøkkeltall;Fields:Metric,Value;Width:0.5}}
```

### Kombinere kolonnebredder og tabellbredde

Du kan kombinere både egendefinerte kolonnebredder og egendefinert tabellbredde.

```
{{List:Usikkerhet;Fields:ID(0.15),Title(0.35),Status(0.5);Width:0.8}}
```

Dette lager en tabell som:
- Spenner over 80% av tilgjengelig bredde
- Har ID-kolonne på 15% av tabellbredden
- Har Title-kolonne på 35% av tabellbredden
- Har Status-kolonne på 50% av tabellbredden

## Felttyper

Skriptet håndterer forskjellige SharePoint-felttyper:

- **Tekstfelt:** Vises som de er
- **Oppslag-felt (enkelt):** Viser oppslagsverdien
- **Oppslag-felt (flere):** Viser alle verdier separert med komma
- **Taksonomi-felt (enkelt):** Viser etiketten fra taksonomiverdien
- **Taksonomi-felt (flere):** Viser alle etiketter separert med komma
- **Tomme felt:** Vises som tomme celler

## Brukseksempler

### Enkel risikoliste
```
{{List:Usikkerhet;Fields:Title}}
```

### Full risikotabell med like kolonner
```
{{List:Usikkerhet;Fields:ID,Title,GtRiskDescription,GtRiskStatus,GtRiskAction}}
```

### Risikotabell med egendefinerte kolonnebredder
```
{{List:Usikkerhet;Fields:ID(0.1),Title(0.25),GtRiskDescription(0.3),GtRiskStatus(0.15),GtRiskAction(0.2)}}
```

### Smal leveransetabell
```
{{List:Prosjektleveranser;Fields:ID(0.1),Title(0.3),GtDeliveryDescription(0.6);Width:0.6}}
```

### Prosjektleveranser med dato
```
Dagens dato: {{Today}}

Prosjektleveranser:
{{List:Prosjektleveranser;Fields:Title(0.3),GtDeliveryDescription(0.5),GtDeliveryResponsible(0.2)}}
```

## Skriptparametere

### Påkrevde parametere
- `ProjectUrl` - URL til SharePoint-prosjektsiden
- `SiteRelativeTemplateFilePath` - Server-relativ sti til malen (`.pptx` eller `.docx`)
- `HubSiteUrl` - URL til hub-siden hvor malen ligger

### Valgfrie parametere
- `TargetLibrary` - Dokumentbibliotek i prosjektsiden (standard: "Delte dokumenter")
- `TargetFolder` - Mappe i dokumentbiblioteket (standard: "Prosjektdokumenter")
- `ClientId` - Azure AD-klient-ID for autentisering (standard: "da6c31a6-b557-4ac3-9994-7315da06ea3a")

## Kjøre skriptet

### Fra Azure Automation
Skriptet bruker automatisk managed identity-autentisering når det kjører i Azure Automation.

### Fra lokalt miljø
Skriptet bruker interaktiv pålogging når det kjøres lokalt. Eksempler:

**PowerPoint:**
```powershell
.\run-pptx.ps1 `
    -ProjectUrl "https://puzzlepart.sharepoint.com/sites/Vino001" `
    -SiteRelativeTemplateFilePath "/Dokumentgenereringsmaler/MAL_Styringsdokument.pptx" `
    -HubSiteUrl "https://puzzlepart.sharepoint.com/sites/pp-vmp"
```

**Word:**
```powershell
.\run-docx.ps1 `
    -ProjectUrl "https://puzzlepart.sharepoint.com/sites/Vino001" `
    -SiteRelativeTemplateFilePath "/Dokumentgenereringsmaler/MAL_Styringsdokument.docx" `
    -HubSiteUrl "https://puzzlepart.sharepoint.com/sites/pp-vmp"
```

## Tekniske detaljer

### Tabellgenerering (PPTX)
- Tabeller er sentrert på lysbildet
- Standard tabellbredde er 95% av lysbildebredden
- Kolonner er jevnt fordelt med mindre egendefinerte bredder er spesifisert
- Overskrifter bruker visningsnavn fra SharePoint-listfelt
- Radhøyden er fast på 370840 EMUer

### Tabellgenerering (DOCX)
- Tabeller er inline i dokumentflyten
- Standard tabellbredde er 95% av tilgjengelig sidebredde (sidebredde minus marger)
- Kolonner er jevnt fordelt med mindre egendefinerte bredder er spesifisert
- Overskrifter bruker visningsnavn fra SharePoint-listfelt med halvfet skrift
- Eksplisitte kantlinjer (single line borders)
- Støtter liggende (landscape) sider - sidedimensjoner leses automatisk fra malen

### Lysbildedimensjoner (PPTX)
Skriptet oppdager automatisk lysbildedimensjonene fra PowerPoint-presentasjonen, og støtter:
- 16:9 størrelsesforhold (standard: 9144000 EMUer bredde)
- 4:3 størrelsesforhold
- Egendefinerte lysbildestørrelser

### Sidedimensjoner (DOCX)
Skriptet leser automatisk sidedimensjoner (`<w:pgSz>`) og marger (`<w:pgMar>`) fra Word-dokumentet. Støtter:
- A4 og Letter format
- Stående og liggende orientering
- Egendefinerte marger

### Token-parsing
Tokens kan være delt opp over flere tekstkjøringer i både PowerPoint og Word. Skriptene slår sammen tekstelementer for å finne komplette tokens selv når Office har delt dem internt.
