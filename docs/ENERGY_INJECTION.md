# Energiegegevens naar Toon sturen

Toon MQTT kan energiegegevens uit Home Assistant, Node-RED, openHAB, Domoticz
of een ander MQTT-systeem aanbieden aan Toons bestaande interne meterobjecten.
Daardoor ziet `happ_pwrusage` de waarden als normale meterupdates; het zijn
niet alleen waarden op de MQTT-tegel.

Op de instellingenpagina **Energie naar Toon** staat naast ieder topic een
vinkje. De hoofdschakelaar zet alle MQTT-injectie aan of uit; de afzonderlijke
vinkjes bepalen welke waarden Toon werkelijk mag overnemen. Wie bijvoorbeeld
al een zonnepanelen-app op Toon gebruikt, kan **Teruglevering**, **Terug laag**
en **Terug hoog** uitvinken en verbruik of gas wel via MQTT injecteren.

Uitgevinkte live waarden worden ook niet door de timeout op nul gezet. Zo kan
Toon MQTT een waarde die door een andere app wordt beheerd niet overschrijven.
Bij een gecombineerd `inject/state`-bericht worden uitgevinkte velden
overgeslagen en de overige ingeschakelde velden normaal verwerkt.

## Welke waarden verwacht Toon?

| MQTT-veld | Eenheid | Type |
| --- | --- | --- |
| `power_w` | W | actueel afgenomen vermogen |
| `production_w` | W | actueel teruggeleverd vermogen |
| `import_low_kwh` | kWh | cumulatieve afname, laag tarief |
| `import_high_kwh` | kWh | cumulatieve afname, hoog tarief |
| `export_low_kwh` | kWh | cumulatieve teruglevering, laag tarief |
| `export_high_kwh` | kWh | cumulatieve teruglevering, hoog tarief |
| `gas_total_m3` | m³ | cumulatieve gasmeterstand |

Alle velden kunnen in één JSON-bericht:

```text
topic: toon/voorbeeld/inject/state
payload: {"power_w":842,"production_w":0,"import_high_kwh":1980.456,"gas_total_m3":1345.678}
```

Of publiceer één getal naar `toon/voorbeeld/inject/<veld>`.

Live vermogens mogen stijgen en dalen. Cumulatieve kWh- en m³-standen mogen
niet dalen; de service weigert zo'n update om kapotte Toon-grafieken te
voorkomen. Gebruik bij een bewust vervangen of geresette bronmeter de knop
**Tellerbeveiliging resetten** op de tegel.

Wanneer de live bron langer dan de ingestelde timeout zwijgt, zet Toon MQTT
alleen de ingeschakelde `power_w` en `production_w` op nul. Tellerstanden en
uitgevinkte live bronnen blijven ongemoeid.

## Home Assistant-blueprint

De meegeleverde
[`Zonneplan energiebrug`](../home-assistant/blueprints/automation/toonmqtt/zonneplan_energy_bridge.yaml)
heeft vier selecteerbare bronnen:

- nettovermogen in W;
- verbruik in kWh;
- teruglevering in kWh;
- gas in m³.

Bij iedere vermogenswijziging publiceert hij de live waarden. Elke vijf
minuten haalt hij de `sum` uit HA's langetermijnstatistieken en publiceert hij
blijvend oplopende totalen. Dit is nodig voor Zonneplan-sensoren die
`vandaag` heten en om middernacht teruglopen.

Vereisten:

- Home Assistant Recorder moet langetermijnstatistieken voor de gekozen
  sensoren hebben;
- de sensoren moeten numeriek zijn en de juiste eenheid hebben;
- de HA MQTT-integratie en Toon moeten dezelfde broker kunnen bereiken;
- het ingevulde basistopic moet exact overeenkomen.

Een bestaande werkelijk cumulatieve slimme-meterstand kan ook rechtstreeks
worden gepubliceerd; gebruik dan de voorbeelden in
[`../home-assistant/automations.yaml`](../home-assistant/automations.yaml).

## Generiek MQTT-voorbeeld

Met Mosquitto of vanuit een shell:

```sh
mosquitto_pub -h mqtt.example.local -p 1883 \
  -u '<mqtt-user>' -P '<mqtt-password>' \
  -t toon/voorbeeld/inject/state \
  -m '{"power_w":842,"production_w":0,"import_high_kwh":1980.456,"gas_total_m3":1345.678}'
```

Gebruik geen retained injectieberichten. De Toon-service bewaart de
geaccepteerde tellerstanden zelf en publiceert de resulterende state retained.

Voor een nettovermogensbron geldt:

```text
power_w      = max(nettovermogen, 0)
production_w = max(-nettovermogen, 0)
```

## Andere domoticasystemen

- **Node-RED:** gebruik een function-node voor de splitsing hierboven en een
  MQTT output-node naar `inject/state`.
- **openHAB:** maak MQTT channels voor de gewenste injectietopics en publiceer
  vanuit een rule; de standaardtopics hebben geen openHAB-installatiegegevens
  nodig.
- **Domoticz:** gebruik een script of Node-RED-flow. Domoticz' eigen
  `domoticz/in`-protocol vereist lokale `idx`-nummers en kan daarom niet
  generiek door een Toon Store-app worden ontdekt.
- **Overig:** ieder systeem dat een numerieke MQTT-payload of het JSON-object
  hierboven kan publiceren is bruikbaar.

De keuzelijst op Toon selecteert dus Home Assistant Discovery of het stabiele
standaard MQTT-contract. Er wordt voor Domoticz/openHAB geen misleidende
automatische configuratie beloofd.

## Water

Water is bewust nog niet geïnjecteerd. Op de onderzochte Toon is geen
betrouwbaar algemeen intern watermeterobject gevonden dat hetzelfde werkt als
de standaard elektriciteits- en gasobjecten. Een willekeurig MQTT-watergetal
kan wel worden gepubliceerd, maar zou daarmee nog geen normale Toon-meterdata
zijn. Dit kan later worden toegevoegd zodra het interne object en de
bijbehorende Toon-applicatie aantoonbaar zijn.
