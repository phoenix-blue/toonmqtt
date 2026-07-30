# Home Assistant

Kies op de Toon-tegel **Home Assistant** en laat automatische configuratie
aanstaan. Toon MQTT publiceert dan retained MQTT Discovery-configuratie onder
de ingestelde discovery-prefix, standaard `homeassistant`.

Na een geldige verbinding verschijnt één Toon-apparaat met:

- een echte `climate`-entiteit met actuele kamerwaarde, actuele
  luchtvochtigheid, doeltemperatuur, verwarmingsactie en presets;
- schakelaars voor weekprogramma en tapwater;
- sensoren voor de beschikbare klimaat-, ketel- en energiewaarden;
- getal-entiteiten voor cv-/tapwaterinstellingen en energie-injectie.

De app luistert naar `homeassistant/status`. Wanneer HA na een herstart
`online` publiceert, worden discovery en de actuele Toon-status opnieuw
aangeboden. Handmatig herladen van MQTT hoort daardoor niet nodig te zijn.

## Thermostaat gebruiken

De entiteit heet normaal `climate.toon_thermostaat`. Wanneer HA al een
gelijknamige entiteit heeft, voegt HA zelf een achtervoegsel toe, bijvoorbeeld
`climate.toon_thermostaat_2`.

Instellen vanuit een automatisering:

```yaml
action: climate.set_temperature
target:
  entity_id: climate.toon_thermostaat
data:
  temperature: 20.5
```

De doeltemperatuur gaat via MQTT naar Toons bestaande
`ChangeSchemeState`-bediening. De presets `comfort`, `home`, `sleep` en `away`
selecteren de corresponderende Toon-temperatuurstand. De schakelaar
**Weekprogramma** kiest tussen schema en handmatig.

De MQTT-climate ondersteunt bewust alleen de modus `heat`: de ketel zelf uit
zetten is geen veilige generieke Toon-opdracht en wordt daarom niet
gesimuleerd.

## Bestaande HA-energiesensoren automatisch doorsturen

Voor een Zonneplan-configuratie is een kant-en-klare blueprint aanwezig:
[`Zonneplan energiebrug`](../home-assistant/blueprints/automation/toonmqtt/zonneplan_energy_bridge.yaml).
Deze gebruikt HA Recorder-langetermijnstatistieken om dagelijks resetende
Zonneplan-totalen om te zetten naar cumulatieve tellerstanden voor Toon.

### Installeren vanuit deze repository

1. Download
   [`zonneplan_energy_bridge.yaml`](../home-assistant/blueprints/automation/toonmqtt/zonneplan_energy_bridge.yaml).
2. Plaats het bestand in
   `/config/blueprints/automation/toonmqtt/zonneplan_energy_bridge.yaml`.
3. Ga in HA naar **Instellingen → Automatiseringen & scènes → Blueprints**.
4. Kies **Toon MQTT - Zonneplan energiebrug**, maak de automatisering en selecteer
   de sensoren en hetzelfde basistopic als op Toon.

Na publicatie op GitHub kan dezelfde blueprint ook met deze import-URL worden
geïmporteerd:

```text
https://github.com/ToonSoftwareCollective/toonmqtt/blob/main/home-assistant/blueprints/automation/toonmqtt/zonneplan_energy_bridge.yaml
```

Kies in de blueprint de bijbehorende sensoren uit jouw Zonneplan-installatie:

- actueel nettovermogen in W;
- verbruik vandaag in kWh;
- teruglevering vandaag in kWh;
- gasverbruik vandaag in m³;
- hetzelfde basistopic als op Toon, bijvoorbeeld `toon/voorbeeld`.

Controleer de sensor-id's in jouw HA voordat je opslaat; een integratie-update
of zelf gekozen naam kan ze veranderen. De blueprint splitst positief
nettovermogen naar verbruik en negatief nettovermogen naar teruglevering.

Meer uitleg over totalen, eenheden, andere bronnen en andere
domoticasystemen staat in
[`ENERGY_INJECTION.md`](ENERGY_INJECTION.md).

## Geen data, maar wel entiteiten

Controleer achtereenvolgens:

1. Druk op **Test verbinding** op Toon; de melding moet
   `Verbinding geslaagd` worden.
2. Controleer of `toon/voorbeeld/availability` in HA `online` is.
3. Controleer of HA en Toon exact dezelfde broker gebruiken.
4. Controleer brokerrechten voor `toon/voorbeeld/#` en
   `homeassistant/#`.
5. Zet automatische configuratie op Toon uit en weer aan, of herstart de
   Toon MQTT-service, wanneer oude retained discovery van een testversie nog
   aanwezig is.

De app publiceert beschikbare waarden elke 5 tot 3600 seconden, afhankelijk
van het gekozen interval. Sensoren die de hardware niet levert worden niet met
een verzonnen nulwaarde gepubliceerd.

De volledige lees-/schrijfmatrix staat in
[`SENSORS_AND_CONTROL.md`](SENSORS_AND_CONTROL.md).
