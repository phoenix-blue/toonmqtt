# Sensoren en bediening

Toon MQTT publiceert alleen waarden die de Toon of de aangesloten ketel
daadwerkelijk heeft bijgewerkt. Daardoor ontstaat geen geloofwaardige maar
onjuiste nulwaarde voor ontbrekende hardware.

## Altijd of normaal beschikbaar op Toon 2

| Functie | HA-entiteit | Lezen | Schrijven |
| --- | --- | --- | --- |
| Thermostaat | `climate` | kamerwaarde, RV, doel, actie, preset | doeltemperatuur en preset |
| Weekprogramma | `switch` | schema/handmatig | schema/handmatig |
| Kamertemperatuur | `sensor` | °C | — |
| Relatieve vochtigheid | `sensor` | % | — |
| TVOC | `sensor` | ppb, indien sensorproces actief | — |
| Geschatte CO₂ | `sensor` | ppm, indien sensorproces actief | — |
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
