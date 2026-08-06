#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
cd "$PROJECT_DIR"

VERSION=$(tr -d '[:space:]' < version.txt)
EXPECTED=${1:-$VERSION}

fail() {
    echo "releasecontrole mislukt: $*" >&2
    exit 1
}

[ "$VERSION" = "$EXPECTED" ] ||
    fail "version.txt bevat $VERSION, verwacht $EXPECTED"

awk -F= -v expected="$EXPECTED" '
    $1 == "version" {
        found = 1
        if ($2 != expected) exit 1
    }
    END { if (!found) exit 1 }
' toonstore.cfg || fail "toonstore.cfg-versie wijkt af"

awk -v expected="$EXPECTED" '
    index($0, "<version>" expected "</version>") { found = 1 }
    END { if (!found) exit 1 }
' ToonRepo-entry.xml || fail "ToonRepo-entry.xml-versie wijkt af"

awk -v expected="$EXPECTED" '
    index($0, "version         = \"" expected "\"") { found = 1 }
    END { if (!found) exit 1 }
' daemon/main.go || fail "daemonversie wijkt af"

for path in \
    ToonmqttApp.qml ToonmqttTile.qml ToonmqttSettings.qml \
    PointSettingRow.qml TabButton.qml qmldir \
    toonmqtt.sh S99toon-mqtt.sh toon-mqtt-service.sh toon_mqtt_client \
    Changelog.txt description/description.txt \
    drawables/MqttLogo.svg drawables/MqttLogoThumbnail.png \
    drawables/ToonmqttIcon.svg \
    home-assistant/blueprints/automation/toonmqtt/zonneplan_energy_bridge.yaml \
    docs/images/toonmqtt_screenshot_1.png \
    docs/images/toonmqtt_screenshot_2.png \
    docs/images/toonmqtt_screenshot_3.png \
    docs/images/toonmqtt_screenshot_4.png
do
    [ -s "$path" ] || fail "vereist bestand ontbreekt of is leeg: $path"
done

[ -s docs/SECURITY.md ] || fail "veiligheidsdocumentatie ontbreekt"

[ -x toon_mqtt_client ] || fail "toon_mqtt_client is niet uitvoerbaar"
[ -x toonmqtt.sh ] || fail "toonmqtt.sh is niet uitvoerbaar"

FILE_INFO=$(file toon_mqtt_client)
case "$FILE_INFO" in
    *"ELF 32-bit"*"ARM"*"statically linked"*) ;;
    *) fail "binary is geen statische 32-bit ARM-binary: $FILE_INFO" ;;
esac

echo "release $EXPECTED is intern consistent"
