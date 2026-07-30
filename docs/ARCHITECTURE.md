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
- De originele energieconfiguratie wordt bij de eerste installatie bewaard in
  `/mnt/data/tsc/backups/toonmqtt-energy-original`.
- De app wijzigt de originele Quby-configuratie niet.

De huidige TSC-helper verwijdert eerst de appmap. De draaiende service merkt
het ontbrekende `/qmf/qml/apps/toonmqtt` vervolgens binnen tien seconden op en
ruimt zijn service-, binary- en opstartkoppelingen op. Gebruikersconfiguratie
en de veiligheidsbackup blijven bewust op `/mnt/data` staan.
