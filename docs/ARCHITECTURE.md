# Architectuur en veiligheid

## Onderdelen

- `ToonmqttApp.qml`: registratie, configuratie, status en TSC-installatieverzoek.
- `ToonmqttTile.qml`: tegel met MQTT-logo en verbindingsstatus.
- `ToonmqttSettings.qml`: broker-, integratie- en energie-instellingen.
- `toon_mqtt_client`: statische Linux ARMv7-service.
- `toonmqtt.sh`: eenmalige/zelfherstellende installatie via het TSC-hulpscript.
- `S99toon-mqtt.sh`: opstartkoppeling voor Toon.

De QML-app schrijft alleen configuratie en korte besturingsverzoeken. Alle
netwerk- en Toon-interactie gebeurt in de afzonderlijke service, zodat de
gebruikersinterface niet blokkeert.

De daemon bemonstert Toon onafhankelijk van MQTT-publicatie. Een genormaliseerde
snapshot bepaalt welke losse topics sinds de vorige meting zijn gewijzigd; een
aparte heartbeat zorgt periodiek voor volledige herpublicatie. De runtime houdt
per punt bron, beschikbaarheid en laatst-gezienmoment bij voor de QML-interface.

Bij een configuratiereload wordt de nieuwe configuratie gelezen terwijl de
oude brokerverbinding nog bestaat. Daardoor kunnen retained state- en Home
Assistant Discovery-records van de vorige namespace eerst worden verwijderd.
Status en diagnose bevatten bewust geen MQTT-wachtwoord.

## Normale Toon-meterketen

De injectie schrijft niet alleen tekst op de MQTT-tegel. De service stuurt een
BoxTalk-notificatie naar de bestaande meterobjecten die ook door
`happ_pwrusage` en de RRD-logger worden gebruikt:

| Waarde | Toon-servicevariabele | Interne eenheid |
| --- | --- | --- |
| Actueel verbruik | `ElectricityFlowMeter/CurrentElectricityFlow` | W |
| Actuele productie | `ElectricityFlowMeter/CurrentElectricityFlow` | W |
| Elektriciteitsteller | `ElectricityQuantityMeter/CurrentElectricityQuantity` | Wh |
| Gasmeterstand | `GasQuantityMeter/CurrentGasQuantity` | liter |

De MQTT-service rekent kWh naar Wh en m3 naar liter om. Het bestaande
`happ_pwrusage` en Toons RRD-proces ontvangen hierdoor normale meterupdates.
Gasdebiet wordt door Toon afgeleid uit opeenvolgende cumulatieve gasstanden.

## Beveiligingen

- Negatieve, niet-numerieke en buitensporig grote waarden worden geweigerd.
- Cumulatieve tellerstanden mogen na acceptatie niet dalen.
- De tellerbeveiliging wordt persistent bewaard in
  `/mnt/data/tsc/toon-mqtt-energy.json`.
- Live W-waarden worden bij uitblijven van berichten automatisch nul.
- De app wijzigt de originele Quby-configuratie niet.

De huidige TSC-helper verwijdert eerst de appmap. Een broker-onafhankelijke
bewakingslus merkt het ontbrekende `/qmf/qml/apps/toonmqtt` vervolgens binnen
enkele seconden op en ruimt de service-, binary-, opstart- en PID-koppelingen
op. De appmap moet vijf seconden onafgebroken ontbreken, zodat de korte
verwijder-/herkoppelfase tijdens een Store-update niet als de-installatie wordt
gezien. Daarna worden ook de door de app beheerde configuratie, inloggegevens,
energiestatus en installatieback-up verwijderd. Historische, handmatig gemaakte
veiligheidsback-ups vallen daar niet onder.
