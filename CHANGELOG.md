# Changelog

## In ontwikkeling

- Toegevoegd: lees- en schrijfvinkjes per datapunt, verdeeld over tabbladen
  voor thermostaat, BXT-sensoren, ketel/OpenTherm, energie en Toon-hardware.
- Toegevoegd: bewerkbare Nederlandse namen voor domotica-entiteiten, zonder
  wijziging van de stabiele technische MQTT-topics.
- Toegevoegd: ruwe lichtintensiteit en Toon-diagnosewaarden zoals CPU,
  geheugen, temperatuur, uptime, opslag en WiFi-tellers.
- Gewijzigd: Home Assistant Discovery en retained state-topics volgen de
  gekozen lees- en schrijfrechten.
- Toegevoegd: afzonderlijke injectievinkjes direct naast de energietopics.
  Uitgeschakelde bronnen worden ook niet meer door de live-data-timeout op nul
  gezet, zodat een andere Toon-app de bron veilig kan blijven beheren.
- Toegevoegd: automatische beschikbaarheids- en bronweergave per datapunt,
  inclusief laatst-gezienstatus en detectie van mogelijke energiebronconflicten.
- Toegevoegd: publicatie bij wijziging, instelbare heartbeat en opruiming van
  oude retained state- en Discovery-records na configuratiewijzigingen.
- Toegevoegd: niet-retained MQTT-events voor beschikbaarheid, storingen,
  bronconflicten, energietimeouts en Toon-hardwarewaarschuwingen.
- Toegevoegd: lokaal veilig diagnoserapport zonder privéconfiguratie of
  meetwaarden.
- Beveiligd: begrensde MQTT-pakketten en opdrachten, strengere configuratie- en
  topicvalidatie en bestandsrechten `0600` voor gevoelige runtimebestanden.
- Gewijzigd: de actieve hoofdtab en datapunt-tab hebben een duidelijk donker
  paarse achtergrond met een lichte onderstreping.

## 1.2.4

- Opgelost: bij het aanpassen van een instelling opent nu een afzonderlijke
  bewerkweergave met het invoerveld boven het schermtoetsenbord. Het actieve
  veld blijft daardoor tijdens het typen volledig zichtbaar.
- Verduidelijkt: Toon MQTT is uitsluitend bedoeld voor Toon 2.

## 1.2.3

- Opgelost: het miniatuur in de tegelkiezer gebruikt nu een op Toon aanwezig
  TSC-symbool met het opschrift `MQTT`. Daardoor blijft de tegel herkenbaar op
  firmwareversies die losse PNG- en SVG-bestanden uit een app-map niet in de
  tegelkiezer laden.

## 1.2.2

- Opgelost: het miniatuur in de tegelkiezer gebruikt nu een contrastrijke PNG
  van het paarse MQTT-logo, omdat Toon directe SVG-miniaturen niet betrouwbaar
  rendert.

## 1.2.1

- Opgelost: bij verwijderen via de ToonStore ruimt de achtergrondservice zijn
  opstart- en servicelinks nu ook op wanneer geen MQTT-broker bereikbaar is.
- Opgelost: ook een eventueel achtergebleven gestopt PID-bestand wordt
  verwijderd.
- Gewijzigd: een nieuwe installatie start met gewone MQTT; Home Assistant
  Discovery staat standaard uit en de bijbehorende velden zijn alleen zichtbaar
  wanneer Home Assistant is geselecteerd.
- Gewijzigd: verwijderen wist alle door de app beheerde configuratie,
  inloggegevens, runtimebestanden en installatieback-up.

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
