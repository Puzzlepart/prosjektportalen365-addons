## Brukerveiledning – Avanserte tillegg i Prosjektportalen

### Hvilke avanserte tillegg finnes?

Avanserte tillegg består per nå av 5 komponenter.

| Komponent | Funksjon | Trigger | Manuell/Automatisk |
| --- | --- | --- | --- |
| **Arkivering av prosjekt** | Setter prosjektet som Arkivert dersom man setter "Ferdig" status i prosjektegenskaper. | Du endrer **prosjektfase** til *"Ferdig"* i prosjektegenskaper. | Automatisk |
| **Reaktivering av prosjekt** | Setter et prosjekt som er Avsluttet og Arkivert aktivt igjen | Du klikker knappen **"Sett prosjekt som aktivt"** i Prosjekter-listen i Prosjektportalen. | Automatisk |
| **Beregning av oppfølgingsdatoer** | Beregner oppfølgingsdatoer på forhåndsdefinerte kriterier (kan tilpasses) | Du fyller inn eller endrer **overleveringsdato** (`GtcHandoverDate`) i prosjektegenskaper. | Automatisk |
| **Bytte av prosjektleder + mappetilgang** | Oppdaterer mappetilganger ved faseendring i byggprosjekt | Du endrer **prosjektfase** (`GtProjectPhase`) i prosjektegenskaper – f.eks. fra Planfase til Byggeplanfase. | Automatisk |
| **Hente prosjektinformasjon** | Henter Prosjektegenskaper på relevant prosjekt | Kalles automatisk av de andre jobbene som en hjelpejobb – Ingen trigger tilgjengelig. | Automatisk |
| **Tilgangsforespørsel** | Sender godkjenningsforespørsel til Prosjektleder og prosjekteier om brukeren kan få tilgang til valgte prosjekter. | Trigges via HTTP kall. Må settes opp fra Dynamisk liste webparten. | Manuell |

Automatiske triggere trigges på generell basis av prosjekter-listen som blir oppdatert av endringer i prosjektegenskaper som synkroniseres til denne listen. Manuelle HTTP triggere kan trigges manuelt, men per nå krever det dynamisk liste webpart som sender med nødvendig informasjon.

---

### 1. Arkivering og reaktivering av prosjektområder

**Hva den gjør:** Tar et prosjektområde inn i et "fryst" tilstand når prosjektet er ferdig, eller åpner det opp igjen om noen trenger å jobbe videre.

**Når et prosjekt arkiveres (prosjektfase settes til "Ferdig"):**

- Prosjektet merkes som **Avsluttet** både på selve prosjektområdet og i hovedoversikten i Prosjektportalen.
- Det legges på et **gult arkivbanner** øverst på området, som tydelig viser at prosjektet er arkivert.
- Området settes til **skrivebeskyttet** – ingen kan endre noe, men alt innhold kan fortsatt leses.
- Tilhørende **Microsoft Teams** arkiveres også, slik at chat og filer låses for endringer.

**Når et prosjekt reaktiveres:**

- Skrivebeskyttelsen fjernes, og brukerne får tilgang til å gjøre endringer igjen.
- Microsoft Teams åpnes opp på nytt.
- Statusen oppdateres tilbake til aktivt, og arkivbanneret fjernes.

> **Tips:** Som administrator trenger du ikke kjøre jobben manuelt. Du bruker SPFx-knappen "Sett prosjekt som aktivt" (se eget avsnitt nedenfor) for å reaktivere et arkivert prosjekt.

---

### 2. Hente informasjon om et prosjektområde

**Hva den gjør:** Plukker ut nøkkelopplysninger om et prosjektområde – som navn, ID-er, hvilken hub det tilhører og hvilken fase det er i.

**Hva den brukes til:**

- Utgangspunkt for andre automatiske jobber (de trenger denne informasjonen for å vite hva de skal jobbe med).
- Feilsøking når noe ikke fungerer som forventet.
- Integrasjon med andre systemer som trenger å vite mer om et prosjekt.

Dette er en hjelpejobb som sjelden er synlig for deg som bruker, men den er en viktig brikke i automatiseringen.

---

### 3. Automatisk oppdatering av prosjektdatoer

**Hva den gjør:** Når en prosjektleder fyller inn **overleveringsdato** på et veiprosjekt, regnes flere viktige oppfølgingsdatoer ut automatisk:

| Dato                | Beregning              | Hva det betyr                                  |
| ------------------- | ---------------------- | ---------------------------------------------- |
| 1-års befaring      | Overleveringsdato + 1 år  | Når befaringen etter første år skal skje        |
| Fravikelsesfrist    | Overleveringsdato + 3 år  | Frist for å melde inn fravik                    |
| Reklamasjonsfrist   | Overleveringsdato + 5 år  | Siste frist for å melde inn reklamasjoner       |

Datoene oppdateres både på selve prosjektområdet og i hovedoversikten i Prosjektportalen, slik at alt er synkronisert.

**Hvorfor er dette nyttig?** Du som prosjektleder slipper å regne ut fristene selv, og det blir aldri feil. Hvis overleveringsdatoen endres, regner systemet ut alle fristene på nytt.

---

### 4. Automatisk valg av prosjektleder basert på fase

**Hva den gjør:** Sørger for at riktig person står som prosjektleder, avhengig av hvor prosjektet er i livsløpet sitt.

**Hvordan det fungerer:**

- I **Planfasen** settes **Planleggingsleder** automatisk som prosjektleder.
- I **alle andre faser** settes **Byggherreleder** som prosjektleder.

Begge feltene fylles ut i prosjektegenskaper når prosjektet opprettes, og når fasen endres bytter systemet automatisk til riktig leder.

**Tilgangsstyring til sensitive mapper:**

I tillegg styrer denne jobben tilganger til mapper hvor det ligger sensitiv informasjon, som tilbud og kontrakter:

- `1 Planfase / 20 Prosjektledelse / Anskaffelser / Tilbud`
- `1 Planfase / 20 Prosjektledelse / Anskaffelser / Kontrakter`
- `2 Byggeplanfase / 10 Byggeplanlegging / Anskaffelser / Tilbud`
- `2 Byggeplanfase / 10 Byggeplanlegging / Anskaffelser / Kontrakter`
- `2 Byggeplanfase / 20 Konkurransegrunnlag og kontrahering / Kontrahering`

**Slik beskyttes mappene:**

- Første gang fasen endres: Mappen får **egne tilganger** (ikke arvet fra resten av området), og kun aktiv prosjektleder får full tilgang.
- Senere: Hvis du som administrator har gitt manuelle tilganger til andre, beholdes disse. Systemet sørger bare for at prosjektlederen alltid har tilgang.

> **Hvorfor er dette viktig?** Tilbud og kontrakter inneholder sensitiv informasjon som ikke alle på prosjektet skal kunne se. Denne automatikken sikrer at innholdet er beskyttet, men samtidig at du som administrator kan gi tilgang til de personene som faktisk trenger det – uten å bli overskrevet av systemet.

---

### Knappen "Sett prosjekt som aktivt" (SPFx-utvidelse)

Dette er en knapp som vises i listen **Prosjekter** i Prosjektportalen, og den lar deg som administrator åpne opp et arkivert prosjekt på nytt.

#### Når vises knappen?

Knappen er bare synlig hvis **alle** disse er sanne:

1. Du er på listen **Prosjekter** i hub-området (Prosjektportalen).
2. Du har valgt **ett (og bare ett) prosjekt** i listen.
3. Du er **områdeadministrator**.
4. Prosjektet har status **"Stengt"** eller **"Avsluttet"** **og** er markert som arkivert.

Hvis prosjektet er aktivt, eller hvis du ikke er administrator, vil knappen ikke vises.

#### Slik bruker du knappen

1. Gå til **Prosjekter**-listen i Prosjektportalen.
2. Marker det arkiverte prosjektet du vil åpne opp igjen (sett en hake foran prosjektet).
3. Klikk på **"Sett prosjekt som aktivt"** i kommandolinjen øverst.
4. En dialog dukker opp og spør om du vil fortsette.

   > *"Du er i ferd med å sette dette prosjektet som aktivt. Det blir da tilgjengelig for at brukere kan gjøre endringer igjen. Vil du fortsette?"*

5. Klikk **"Sett som aktivt"** for å bekrefte, eller **"Avbryt"** for å gå tilbake.
6. Du får en bekreftelse: *"Prosjektet vil nå bli aktivt. Dette tar noen minutter."*
7. Lukk dialogen og vent. I løpet av få minutter vil:
   - Skrivebeskyttelsen fjernes fra prosjektområdet
   - Microsoft Teams åpnes opp igjen
   - Statusen settes til **"Aktivt"**
   - Arkivbanneret forsvinner

#### Hvis noe går galt

Hvis du får en feilmelding (*"Noe gikk galt. Prosjektet ble ikke aktivert."*):

- Prøv på nytt etter et par minutter.
- Sjekk at du fortsatt har administratortilgang.
- Kontakt brukerstøtte hvis problemet vedvarer.

---

### Hvordan henger det hele sammen?

Når du klikker **"Sett prosjekt som aktivt"**, skjer dette i bakgrunnen:

1. Knappen sender en beskjed til en automatisk jobb i Azure.
2. Jobben kjører Runbooken for **arkivering/reaktivering** med status "Aktivt".
3. Runbooken låser opp prosjektområdet, åpner Teams og oppdaterer status.
4. Når jobben er ferdig, er prosjektet aktivt igjen for alle brukere.

Du trenger ikke vite detaljene – men det er greit å vite at dette tar noen minutter, og at både SharePoint-området og det tilhørende Teams-rommet blir reaktivert samtidig.

---

### Oppsummering

| Oppgave | Hvem starter den? | Hva må du gjøre? |
| --- | --- | --- |
| Arkivere prosjekt | Automatisk når prosjektfase = Ferdig | Endre prosjektfase til "Ferdig" |
| Reaktivere prosjekt | Du, via "Sett prosjekt som aktivt" | Klikk knappen i Prosjekter-listen |
| Hente prosjektinformasjon | Automatisk (hjelpejobb) | Ingenting |
| Beregne oppfølgingsdatoer | Automatisk når overleveringsdato endres | Fyll inn overleveringsdato |
| Sette riktig prosjektleder | Automatisk når fase endres | Endre fase på prosjektet |
| Beskytte mapper for tilbud og kontrakter | Automatisk ved første faseendring | Eventuelt gi manuelle tilganger ved behov |
| Forespørre tilgang | Bruker uten tilgang til prosjekt | Velge prosjekter og trykke på knapp

---

### Trenger du hjelp?

Send e-post til brukerstøtte hvis du opplever problemer med avanserte tillegg.