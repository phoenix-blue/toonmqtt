# Sensoren en bediening

Toon MQTT publiceert alleen waarden die de Toon of de aangesloten ketel
daadwerkelijk heeft bijgewerkt. Daardoor ontstaat geen geloofwaardige maar
onjuiste nulwaarde voor ontbrekende hardware.

## Selecteren op de Toon

Onder **Datapunten** staan vijf tabbladen: Thermostaat, BXT-sensoren,
Ketel/OT, Energie en Toon hardware. Per regel betekent **Lezen** dat Toon MQTT
de waarde naar MQTT publiceert en, bij Home Assistant, de bijbehorende
Discovery-entiteit aanmaakt. **Schrijven** bepaalt of een binnenkomend
bedienings- of injectiebericht voor dat punt wordt geaccepteerd. Een streepje
betekent dat het punt bewust alleen-lezen is.

De technische topicnamen blijven stabiel. Het bewerkbare Nederlandse
naamveld verandert uitsluitend de zichtbare naam in Home Assistant en andere
domoticasystemen, zodat bestaande MQTT-automatiseringen niet breken. Bij een
update zonder opgeslagen puntkeuzes blijven de eerdere lees- en
schrijfmogelijkheden standaard actief.

Iedere regel toont ook de vastgestelde bron en beschikbaarheid. Een punt dat
nog nooit een geldige waarde heeft geleverd wordt grijs weergegeven. Na een
korte meetonderbreking blijft een eerder aangetroffen punt gedurende een
gratieperiode beschikbaar, zodat één mislukte lokale uitlezing niet meteen een
foutmelding veroorzaakt. OpenTherm-punten die de ketel nooit bijwerkt blijven
zichtbaar maar worden als **Niet aangetroffen** gemarkeerd.

## Altijd of normaal beschikbaar op Toon 2

| Functie | HA-entiteit | Lezen | Schrijven |
| --- | --- | --- | --- |
| Thermostaat | `climate` | kamerwaarde, RV, doel, actie, preset | doeltemperatuur en preset |
| Weekprogramma | `switch` | schema/handmatig | schema/handmatig |
| Kamertemperatuur | `sensor` | °C | — |
| Relatieve vochtigheid | `sensor` | % | — |
| TVOC | `sensor` | ppb, indien sensorproces actief | — |
| Geschatte CO₂ | `sensor` | ppm, indien sensorproces actief | — |
| Omgevingslicht | `sensor` | ruwe telling van Toons lichtsensor | — |
| Branderstatus | `binary_sensor` en `sensor` | actief/type | — |
| Ketelmodulatie | `sensor` | % | — |
| Tapwater voorverwarmen | `switch` | aan/uit | aan/uit |
| Tapwaterdoel | `number` | °C | 30–65 °C |
| Maximale cv-temperatuur | `number` | °C | 30–90 °C |
| Maximaal cv-vermogen | `number` | kW | 1–40 kW |
| Temperatuurcorrectie | `number` | °C | -5–5 °C |
| Energie/gas | `sensor` | actueel en gemiddelden indien aanwezig | via injectietopics |

Een standaard Toon 2-binnenklimaatsensor meet geen fijnstof (PM1/PM2.5/PM10).
TVOC en eCO₂ zijn luchtkwaliteitsindicaties en mogen niet als fijnstofmeting
worden gepresenteerd.

De waarden voor temperatuur, relatieve vochtigheid, TVOC, eCO₂ en licht worden
waar mogelijk uit Toons lokale BXT-sensorendpoint gelezen. De lichtwaarde is
een ruwe intensiteitstelling; zonder bekende kalibratie wordt deze niet als
lux aangeduid. De `primary_*`-velden zijn de ruwe ENS210-waarden en kunnen
afwijken van de door Toon gecorrigeerde kamerwaarden.

## Toon-hardwarediagnose

Het tabblad **Toon hardware** kan de volgende alleen-lezen waarden publiceren:

| Datapunt | Eenheid | Standaard actief |
| --- | --- | --- |
| CPU-belasting | % | ja |
| Systeembelasting, 1 minuut | getal | nee |
| Geheugengebruik | % | ja |
| Beschikbaar geheugen | MB | nee |
| Processortemperatuur | °C | ja |
| Uptime | uur | ja |
| Opslaggebruik systeem en gegevens | % | nee |
| Ontvangen en verzonden WiFi-data | MB | nee |

Deze waarden zijn diagnosegegevens van de Toon zelf. Ze bedienen geen
hardware en worden in Home Assistant als diagnostische entiteiten opgenomen.

## Optionele OpenTherm-waarden

De service leest Toons `printTableInfo` en decodeert alleen OpenTherm-velden
waarvan de `updated`-waarde groter dan nul is:

- ketel-aanvoer- en retourtemperatuur;
- cv-waterdruk;
- actuele tapwatertemperatuur en tapwaterdebiet;
- door de ketel gemelde buitentemperatuur;
- rookgastemperatuur;
- ketelcapaciteit en minimale modulatie;
- brander-/pompstarts en bedrijfsuren;
- OEM-diagnosecode en OpenTherm-slaveversie.

Welke velden verschijnen hangt af van ketel, Toon-aansluiting en
OpenTherm-ondersteuning. Niet iedere ketel implementeert elk protocol-ID.
Diagnose- en urenteller-entiteiten staan in HA standaard uit en kunnen op de
apparaatpagina worden ingeschakeld.

Op de tijdens ontwikkeling onderzochte Toon stonden alle uitgebreide
OpenTherm-tabelregels op `updated: 0`. Daar zijn dus op dit moment geen
betrouwbare aanvoer-, retour- of drukwaarden beschikbaar; de app laat ze
terecht weg. De gewone Toon-ketelstatus en modulatie blijven wel beschikbaar.

## Schrijfgrenzen

Schrijven gebruikt bestaande Toon BoxTalk-acties en leest instellingen eerst
terug voordat één veld wordt gewijzigd. Alle opdrachten hebben grenscontrole.
Toch zijn ketelinstellingen zoals maximale cv-temperatuur en vermogen
installateursinstellingen: wijzig ze alleen wanneer de ketel/installatie dat
toelaat.

De ruwe fout- en verbindingscodes zijn diagnose-informatie. De app maakt daar
geen automatische reset- of ketelcommando's van.
