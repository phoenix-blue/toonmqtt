# Toon MQTT

Lokale MQTT-koppeling voor een geroot Eneco/Quby Toon 2. De app toont een tegel
op Toon, publiceert de beschikbare thermostaat-, klimaat-, ketel- en
energiegegevens en accepteert bedienings- en meterwaarden via MQTT.

Deze app is uitsluitend bedoeld voor **Toon 2**. De vermelding `toon2only` in
de TSC-catalogus voorkomt installatie op een Toon 1.

Versie 1.2.5 is bedoeld voor installatie via de TSC Store. Na installatie
plaatst de app zelf de achtergrondservice en opstartkoppeling; er zijn op Toon
geen handmatige SSH-commando's nodig.

## Mogelijkheden

- Instellen vanaf de tegel: broker, poort, gebruikersnaam, wachtwoord,
  basistopic en publicatie-interval. Een nieuwe installatie begint met gewone
  MQTT, zonder afhankelijkheid van een domoticasysteem.
- Per tabblad bepalen welke thermostaat-, BXT-, ketel-, energie- en
  hardwarepunten worden gepubliceerd of bediend. Elk datapunt heeft een
  Nederlandse standaardnaam die op het scherm kan worden aangepast.
- Automatische beschikbaarheidsweergave met bronvermelding, laatst-gezienstatus
  en waarschuwingen voor mogelijke dubbele energiebronnen.
- Keuze uit Standaard MQTT, Home Assistant, Domoticz en openHAB. Automatische
  discovery-instellingen verschijnen alleen bij Home Assistant; de andere
  profielen gebruiken het gedocumenteerde standaard MQTT-contract.
- Home Assistant MQTT Discovery voor sensoren, een echte `climate`-thermostaat,
  schakelaars,
  instellingen en energie-injectie.
- Publicatie van onder meer temperatuur, luchtvochtigheid, TVOC/eCO2,
  thermostaatstatus, setpoint, ketelmodulatie, beschikbare OpenTherm-data en
  energiegegevens. Optionele diagnoses omvatten CPU-belasting, geheugen,
  processortemperatuur, uptime, opslag en WiFi-tellers.
- Bediening van setpoint, preset, weekprogramma, tapwater- en cv-instellingen.
- Injectie van actueel verbruik, teruglevering, kWh-tellerstanden en de
  gasmeterstand in Toons normale interne meterketen. Iedere injectiewaarde kan
  afzonderlijk worden uitgevinkt wanneer een andere Toon-app die bron beheert.
- Veilige grenscontroles, een monotone-tellerbeveiliging en automatische
  nulstelling van verouderde live vermogenswaarden.
- Publicatie bij wijziging met een instelbare volledige heartbeat, automatische
  opruiming van oude retained topics en afzonderlijke MQTT-gebeurtenissen.
- Een veilig diagnoserapport zonder brokeradres, account, wachtwoord, topics,
  meetwaarden of aangepaste namen.

Een Toon 2 meet geen fijnstof met de standaard binnenklimaatsensor. Indien
aanwezig worden TVOC en de geschatte CO2-waarde gepubliceerd.

## Installatie

Wanneer de app in de TSC Store is opgenomen:

1. Open de TSC Store op Toon en installeer **Toon MQTT**.
2. Voeg de tegel toe.
3. Open de tegel, vul de brokergegevens in en druk op **Opslaan**.
4. Gebruik **Test verbinding** om broker en aanmelding te controleren.

De MQTT-configuratie wordt op Toon bewaard in
`/mnt/data/tsc/toon-mqtt.json`. Het wachtwoord staat daar leesbaar in en moet
daarom een afzonderlijk lokaal MQTT-account met beperkte rechten zijn.

## Updates en verwijderen

Een normale update via de ToonStore bewaart de bestaande MQTT-configuratie,
inloggegevens, integratiekeuze en energiestatus. De installer maakt alleen een
nieuwe standaardconfiguratie wanneer nog geen configuratiebestand bestaat.

Verwijderen via de ToonStore is bewust anders: dit stopt de daemon en wist alle
door Toon MQTT beheerde servicekoppelingen, runtimebestanden, configuratie en
inloggegevens. Een latere herinstallatie begint daardoor weer met de neutrale
standaardinstellingen voor gewone MQTT.

Reeds door Toon opgeslagen meetgeschiedenis wordt niet gewist. Alleen de
actuele geïnjecteerde verbruiks- en productiewaarden worden bij verwijderen op
nul gezet.

## Energie vanuit Home Assistant

De app ontvangt live vermogen in W en tellerstanden in kWh of m³. Voor Home
Assistant zijn een universele sensor-naar-Toon-blueprint en een afzonderlijke
Zonneplan-blueprint voor dagelijks resetende tellers meegeleverd. De universele
variant ondersteunt onder meer HomeWizard P1- en DSMR-sensoren. Voor andere
systemen staan generieke voorbeelden in
[`docs/ENERGY_INJECTION.md`](docs/ENERGY_INJECTION.md).

### Universele energieblueprint

**Documentatie-update 9 september 2026:** de universele Home
Assistant-blueprint is toegevoegd. Dit is geen wijziging aan de Toon-app en
vereist daarom geen nieuwe installatie of update op Toon.

De blueprint staat in
[`home-assistant/blueprints/automation/toonmqtt/universal_energy_bridge.yaml`](home-assistant/blueprints/automation/toonmqtt/universal_energy_bridge.yaml)
en is geschikt voor HomeWizard P1, DSMR en andere sensoren met cumulatieve
elektriciteits- en gasstanden.

Installeren in Home Assistant:

1. Download `universal_energy_bridge.yaml` uit deze repository.
2. Plaats het bestand in
   `/config/blueprints/automation/toonmqtt/universal_energy_bridge.yaml`.
3. Herlaad de automatiseringen of herstart Home Assistant.
4. Ga naar **Instellingen > Automatiseringen & scènes > Blueprints** en maak
   een automatisering met **Toon MQTT - Universele energiebrug**.
5. Vul hetzelfde MQTT-basistopic in als op Toon en koppel alleen de sensoren
   die in jouw installatie beschikbaar zijn.

Gebruik voor een HomeWizard P1 Meter de optie **Eén gesigneerde
nettovermogenssensor** met **Positief is afname**. Koppel daarna, indien
beschikbaar, de cumulatieve afname-, terugleverings- en gasmeters. Laat een
ontbrekend veld leeg. Koppel een gecombineerd totaal aan slechts één
tariefveld om dubbeltelling te voorkomen.

De bestaande Zonneplan-blueprint blijft beschikbaar voor sensoren die iedere
dag naar nul terugkeren. Meer uitleg en de volledige veldkoppeling staan in
[`docs/ENERGY_INJECTION.md`](docs/ENERGY_INJECTION.md).

De belangrijkste topics zijn:

```text
toon/voorbeeld/inject/power_w
toon/voorbeeld/inject/production_w
toon/voorbeeld/inject/import_low_kwh
toon/voorbeeld/inject/import_high_kwh
toon/voorbeeld/inject/export_low_kwh
toon/voorbeeld/inject/export_high_kwh
toon/voorbeeld/inject/gas_total_m3
```

Zie [`docs/TOPICS.md`](docs/TOPICS.md) voor alle state-, set- en injectietopics.

MQTT wordt op Toon 2 zonder TLS gebruikt. Gebruik een afzonderlijk account,
beperkte broker-ACL's en uitsluitend een vertrouwd lokaal netwerk. Zie
[`docs/SECURITY.md`](docs/SECURITY.md).

## Documentatie

- [`docs/HOME_ASSISTANT.md`](docs/HOME_ASSISTANT.md)
- [`docs/ENERGY_INJECTION.md`](docs/ENERGY_INJECTION.md)
- [`docs/SENSORS_AND_CONTROL.md`](docs/SENSORS_AND_CONTROL.md)
- [`docs/TOPICS.md`](docs/TOPICS.md)
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- [`docs/TSC_STORE.md`](docs/TSC_STORE.md)
- [`docs/SECURITY.md`](docs/SECURITY.md)

## Ontwikkelen

De QML-bestanden staan in de repositoryroot. De achtergrondservice staat in
`daemon/` en wordt als statische ARMv7-binary meegeleverd:

```sh
./scripts/build.sh
```

Voor een release moeten `version.txt`, `toonstore.cfg`, de Go-constante
`version`, `Changelog.txt` en het TSC-catalogusfragment dezelfde versie hebben.

## Licentie en logo

De broncode valt onder de MIT-licentie. `drawables/MqttLogo.svg` is het MQTT
woord-/beeldmerk van OASIS; zie de opmerkingen in dat bestand en gebruik het in
overeenstemming met het merkbeleid van OASIS.
