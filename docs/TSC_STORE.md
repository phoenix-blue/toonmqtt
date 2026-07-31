# Publiceren in de TSC Store

De repository is ingericht voor het bestaande download- en versieproces van
de Toon Software Collective.

## Eerste publicatie

1. Laat een TSC-beheerder de repository aanmaken/importeren met exact het pad
   `ToonSoftwareCollective/toonmqtt`. Alleen een persoonlijke fork of een
   repository onder een andere organisatie is niet voldoende.
2. Controleer dat het ARMv7-bestand `toon_mqtt_client` uitvoerbaar in de
   repository staat.
3. Maak een Git-tag met exact dezelfde waarde als `version.txt`, voor deze
   release `1.2.3`.
4. Voeg [`ToonRepo-entry.xml`](../ToonRepo-entry.xml) toe aan `ToonRepo.xml`
   in `ToonSoftwareCollective/toonstore_AppRepository`.
5. Voeg de Store-screenshots uit `docs/images` aan die repository toe met
   dezelfde bestandsnamen.

De Store haalt vervolgens de tag op, installeert die als
`/qmf/qml/apps/toonmqtt-<versie>` en maakt de gebruikelijke symlink
`/qmf/qml/apps/toonmqtt`.

Dit organisatiepad is een harde eis van de huidige TSC-helper: die vraagt tags
en tarballs op via
`api.github.com/repos/ToonSoftwareCollective/<folder>/...`. `toonstore.cfg` is
nuttige projectmetadata, maar bepaalt deze download-URL niet.

Bij de eerste QML-start schrijft de app `external-toonmqtt` naar het
TSC-opdrachtbestand. Het bestaande TSC-hulpscript voert daarna `toonmqtt.sh`
uit. Dat script:

- maakt alleen indien nodig de gebruikersconfiguratie;
- installeert de achtergrondservice en bootkoppeling;
- start de MQTT-service.

Daarom hoeft een eindgebruiker na een Store-installatie geen SSH-commando's uit
te voeren.

## Catalogus-PR

De catalogus staat in
[`ToonSoftwareCollective/toonstore_AppRepository`](https://github.com/ToonSoftwareCollective/toonstore_AppRepository).
Maak daar een pull request die:

- het fragment uit [`ToonRepo-entry.xml`](../ToonRepo-entry.xml) één keer in
  `ToonRepo.xml` toevoegt;
- `toonmqtt_screenshot_1.png` en `toonmqtt_screenshot_2.png` uit
  [`images`](images) in de catalogusroot zet;
- dezelfde `folder` (`toonmqtt`) en versie (`1.2.3`) gebruikt als de
  applicatierepository/tag.

Vraag vóór samenvoegen ook dat een beheerder bevestigt dat
`https://github.com/ToonSoftwareCollective/toonmqtt` bestaat en de tag
bereikbaar is. Anders ziet de Store de app wel, maar faalt installatie.

## Updatechecklist

- Werk de versie bij in `version.txt`, `toonstore.cfg`, `daemon/main.go`,
  `CHANGELOG.md`, `Changelog.txt` en `ToonRepo-entry.xml`.
- Bouw de ARMv7-binary opnieuw met `scripts/build.sh`.
- Draai `scripts/check-release.sh 1.2.3`.
- Test configuratiebehoud bij een update.
- Test tegel, keuzelijst, beide instellingenpagina's en verbindingstest.
- Test ten minste `inject/power_w`, zet de testwaarde daarna terug naar 0.
- Herstart Toon volledig en controleer service, tegel en brokerverbinding.
- Maak en push de nieuwe Git-tag.
- Werk de versie in de Store-catalogus bij.

Een tag mag pas worden gezet nadat de exacte commit is gebouwd en getest.
Omdat GitHub de bronarchieven uit de tag maakt, moet de binary al in die commit
staan; een los release-asset wordt door de huidige TSC-installer niet gebruikt.
