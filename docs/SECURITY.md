# Veiligheid

Toon MQTT is bedoeld voor een geroot Toon 2-apparaat en een MQTT-broker op een
vertrouwd lokaal netwerk. De app opent geen extra webserver of luisterpoort en
benadert voor Toon-data uitsluitend lokale endpoints op `127.0.0.1`.

## Beschermde gegevens

- De MQTT-configuratie en energiestatus krijgen bestandsrechten `0600`.
- Het MQTT-wachtwoord verschijnt niet in status-, event- of
  diagnoseberichten.
- Het veilige diagnoserapport bevat geen brokeradres, account, wachtwoord,
  topics, meetwaarden of aangepaste namen.
- Binnenkomende MQTT-pakketten zijn begrensd tot 1 MiB; bedieningsberichten tot
  64 KiB. Configuratievelden, topics, poorten, namen en schrijfwaarden worden
  gevalideerd en begrensd.
- Schrijfopdrachten zijn standaard alleen mogelijk voor expliciet ondersteunde
  punten en blijven onderworpen aan de ingestelde grenswaarden.

Het diagnoserapport staat na aanmaken in
`/mnt/data/tsc/toon-mqtt-diagnostics.json`, is alleen lokaal leesbaar en wordt
bij verwijderen van de app gewist.

## Netwerkbeveiliging

De huidige Toon 2-client gebruikt gewone MQTT over TCP. Daarbij is geen TLS
beschikbaar en kunnen brokergegevens en meetwaarden op een onbetrouwbaar
netwerk worden afgeluisterd. Gebruik daarom:

- een broker op hetzelfde vertrouwde LAN of IoT-VLAN;
- een afzonderlijk MQTT-account voor Toon;
- broker-ACL's die alleen het gekozen basistopic toestaan;
- geen rechtstreekse port-forward of internettoegang naar MQTT of Toon;
- een firewallregel waardoor Toon alleen de benodigde lokale broker kan
  bereiken.

Geef Toon onder zijn basistopic publicatierechten voor `availability`,
`state/#`, `event/#`, `command_result`, `inject_result` en `test`. Geef alleen
abonneerechten voor `set/#` en de werkelijk gebruikte `inject/#`-topics.
Voor Home Assistant Discovery is daarnaast publicatierecht op de gekozen
discovery-prefix nodig.

## Vertrouwensgrens

Een geroot Toon-systeem heeft geen sterke scheiding tussen lokale QML-apps:
software die al als root op Toon draait kan ook andere lokale bestanden lezen.
Installeer daarom alleen apps uit een vertrouwde bron en publiceer nooit een
onbewerkt configuratiebestand in een issue of forumreactie. Gebruik daarvoor
uitsluitend het veilige diagnoserapport.
