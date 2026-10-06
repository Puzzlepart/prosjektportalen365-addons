# Avanserte tillegg

## Om løsningen

Avanserte tillegg automatiserer prosjektadministrasjon i Prosjektportalen. Når prosjektegenskapene endres,
oppdateres arkivstatus, oppfølgingsdatoer, prosjektleder og mappetilganger automatisk.

| Komponent | Funksjon | Trigger | Type |
| --- | --- | --- | --- |
| **Arkivering av prosjekt** | Setter prosjektet som arkivert | Prosjektfase settes til *"Ferdig"* | Automatisk |
| **Reaktivering av prosjekt** | Åpner et arkivert prosjekt igjen | Knappen **"Sett prosjekt som aktivt"** i Prosjekter-listen | Manuell |
| **Oppfølgingsdatoer** | Beregner befarings-, fravikelses- og reklamasjonsfrist | **Overleveringsdato** (`GtcHandoverDate`) fylles inn/endres | Automatisk |
| **Prosjektleder + mappetilgang** | Bytter prosjektleder og styrer tilgang til anskaffelsesmapper | **Prosjektfase** (`GtProjectPhase`) endres | Automatisk |
| **Hente prosjektinformasjon** | Henter prosjektegenskaper som hjelpejobb for de andre komponentene | Kalles internt av andre jobber | Automatisk |
| **Tilgangsforespørsel** | Sender godkjenning til prosjektleder/-eier om tilgang til valgte prosjekter | HTTP-kall fra Dynamisk liste-webpart | Manuell |

## Knappen "Sett prosjekt som aktivt"

Kommandoen **"Sett prosjekt som aktivt"** ligger i `Prosjekter`-listen og lar en områdeadministrator reaktivere
et arkivert prosjekt. Området blir skrivbart igjen for brukerne.

Kommandoen vises bare når alle disse er sanne:

- lista heter `Prosjekter`
- nøyaktig ett prosjekt er valgt
- du er områdeadministrator
- prosjektet er arkivert: `GtProjectLifecycleStatus` er `Avsluttet` og `GtIsArchived` er `Ja`

Ved arkivering blir prosjektet merket **Avsluttet**, får et arkivbanner, settes skrivebeskyttet og tilhørende
Microsoft Teams arkiveres. Reaktivering gjør dette omvendt.

1. Marker det arkiverte prosjektet i **Prosjekter**-listen.
2. Klikk **"Sett prosjekt som aktivt"** i kommandolinjen og bekreft i dialogen.
3. Vent noen minutter. I bakgrunnen fjernes skrivebeskyttelsen, Teams åpnes igjen, status settes til
   **"Aktivt"** og arkivbanneret forsvinner.

Får du feilmeldingen *"Noe gikk galt. Prosjektet ble ikke aktivert."*, prøv igjen om et par minutter. Sjekk at
du fortsatt har administratortilgang, og kontakt brukerstøtte hvis problemet vedvarer.

## Automatikk

- **Oppfølgingsdatoer** – Overleveringsdatoen beregner automatisk 1-års befaring (+1 år), fravikelsesfrist
  (+3 år) og reklamasjonsfrist (+5 år). Fristene beregnes på nytt hvis datoen endres.
- **Prosjektleder og mappetilgang** – I Planfasen brukes Planleggingsleder som prosjektleder. I andre faser
  brukes Byggherreleder. Systemet sikrer den aktive prosjektlederen tilgang til anskaffelsesmapper uten å fjerne
  tilganger som administratorer har gitt manuelt.
- **Prosjektinformasjon** – En hjelpejobb henter nødvendig prosjektinformasjon for de automatiske jobbene.
- **Tilgangsforespørsel** – Dynamisk liste-webparten kan sende en godkjenningsforespørsel til prosjektleder og
  prosjekteier når en bruker ber om tilgang til valgte prosjekter.

## Forutsetninger

- Du må ha rollen **områdeadministrator** for å se og bruke reaktiveringsknappen.
- Prosjektegenskaper og Prosjekter-listen i hub-området må være synkronisert for at automatikken skal fungere.
- Arkiverte prosjekter må ha status `Avsluttet` og være markert med `GtIsArchived` for å kunne reaktiveres.

## Trenger du hjelp?

Send e-post til brukerstøtte hvis du opplever problemer med avanserte tillegg.

## Disclaimer

**THIS CODE IS PROVIDED _AS IS_ WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.**