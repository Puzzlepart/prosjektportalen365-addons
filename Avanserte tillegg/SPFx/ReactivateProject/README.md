# reactivate-project

![SPFx](https://img.shields.io/badge/SPFx-1.23.2-green.svg)

## Om løsningen

Legger kommandoen **Sett prosjekt som aktivt** til i `Prosjekter`-lista i Prosjektportalen, slik at en
områdeadministrator kan reaktivere et arkivert prosjekt. Prosjektet blir da skrivbart igjen for brukerne.

Kommandoen er en SPFx `ListViewCommandSet`-utvidelse, og vises bare når alle disse er sanne:

- lista heter `Prosjekter`
- nøyaktig ett prosjekt er valgt
- brukeren er områdeadministrator
- prosjektet er arkivert — `GtProjectLifecycleStatus` er `Avsluttet` og `GtIsArchived` er `Ja`

![Kommandoen i ribbon når et arkivert prosjekt er valgt](./ReactivateProject.png)

Ved bekreftelse gjentar dialogen `Tittel`, `GtProjectLifecycleStatus` og `GtProjectPhaseText` for det valgte
prosjektet, slik at du ser hva du er i ferd med å reaktivere.

![Bekreftelsesdialog med prosjektdetaljer](./ReactivateProjectConfirm.png)

Selve reaktiveringen gjøres ikke av utvidelsen. Den sender en HTTP `POST` med `{ Url, Status: "Aktivt" }` til
URL-en som er konfigurert i `azureFunctionUrl`-egenskapen på custom action (i dag en Azure Logic App), og den
arbeidsflyten oppdaterer prosjektet. Dialogen melder tilbake ved svar `200`/`202` at endringen tar noen minutter.

## Forutsetninger

- Node.js 22.14 eller nyere (< 23) for å bygge løsningen
- Brukeren må være områdeadministrator for å se kommandoen
- En HTTP-trigget arbeidsflyt som tar imot `{ Url, Status }`. URL-en settes i `azureFunctionUrl` i
  `sharepoint/assets/elements.xml` og `sharepoint/assets/ClientSideInstance.xml` for deploy, og i
  `config/serve.json` for lokal debugging

## Utvikling

```bash
npm install
npm run serve      # gulp serve mot lista i config/serve.json
npm run package    # clean + bundle + package-solution -> sharepoint/solution/pp-reactivate-project.sppkg
```

Dev-sertifikatet må stoles på én gang per maskin med `npx gulp trust-dev-cert`.

Versjonsnummeret settes i `package.json`. En `version-sync`-task synker det til `solution.version` i
`config/package-solution.json` ved bygg, men `features[].version` må bumpes manuelt.

## Versjonshistorikk

| Versjon | Dato              | Endring                                                                                   |
| ------- | ----------------- | ----------------------------------------------------------------------------------------- |
| 1.2.0   | 20. august 2026   | SPFx 1.23.2 og Fluent UI v8, nytt ikon, prosjektdetaljer i dialogen, fiks av synlighet     |
| 1.1.0   | 6. februar 2025   | Første versjon                                                                            |

## Disclaimer

**THIS CODE IS PROVIDED _AS IS_ WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.**
