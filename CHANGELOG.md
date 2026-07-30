# Changelog

## 1.2.0

- Toegevoegd: echte Home Assistant MQTT-klimaatentiteit met actuele
  temperatuur, luchtvochtigheid, setpoint, verwarmingsactie en presets.
- Toegevoegd: automatische herpublicatie van discovery na een Home
  Assistant-herstart.
- Toegevoegd: beschikbare OpenTherm-aanvoer-, retour-, druk-, tapwater-,
  brander- en bedrijfsuurwaarden; nooit bijgewerkte ketelvelden worden
  overgeslagen.
- Toegevoegd: afzonderlijke sensoren voor gemiddelde energie- en gaswaarden,
  branderstatus en Toon-diagnosevelden.
- Opgelost: losse kamertemperatuursensor gebruikte een niet-gepubliceerd
  state-topic.
- Gewijzigd: alleen het Home Assistant-profiel publiceert HA Discovery;
  Domoticz en openHAB gebruiken de gedocumenteerde standaard MQTT-topics.
- Toegevoegd: releasecontrole, tests en uitgebreide TSC-, HA-, energie- en
  sensordocumentatie.

## 1.1.0

- Toegevoegd: uitklapkeuze voor standaard MQTT, Home Assistant, Domoticz en
  openHAB.
- Toegevoegd: Home Assistant MQTT Discovery.
- Toegevoegd: MQTT-bediening van thermostaat-, tapwater- en cv-instellingen.
- Toegevoegd: energie-injectie voor live verbruik/productie, vier
  elektriciteitstellers en de gasmeterstand.
- Toegevoegd: tellerbeveiliging, live-data-timeout en persistente injectiestatus.
- Toegevoegd: automatische service-installatie en bootstart via TSC.
- Gewijzigd: MQTT-logo en uitgebreid instellingenvenster.
- Opgelost: betrouwbare verbindingstest en directe statusuitlezing.

## 1.0.0

- Eerste werkende Toon-tegel met lokale MQTT-publicatie.
