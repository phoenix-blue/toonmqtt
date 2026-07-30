#!/bin/sh

# Wordt automatisch uitgevoerd door het bestaande TSC-hulpscript wanneer
# ToonmqttApp.qml "external-toonmqtt" naar /tmp/tsc.command schrijft.

APP_DIR=/qmf/qml/apps/toonmqtt
CONFIG=/mnt/data/tsc/toon-mqtt.json
BACKUP_DIR=/mnt/data/tsc/backups/toonmqtt-energy-original
SERVICE_LINK=/qmf/bin/toon-mqtt-service.sh
BINARY_LINK=/qmf/bin/toon_mqtt_client
BOOT_LINK=/etc/rc5.d/S99toon-mqtt

install_app() {
    mkdir -p /mnt/data/tsc "$BACKUP_DIR" /var/volatile/log

    if [ ! -f "$BACKUP_DIR/config_happ_pwrusage.xml" ]; then
        cp -a /mnt/data/qmf/config/config_happ_pwrusage.xml "$BACKUP_DIR/" 2>/dev/null
        cp -a /mnt/data/qmf/config/config_hcb_rrd.xml "$BACKUP_DIR/" 2>/dev/null
        cp -a /mnt/data/qmf/config/config_hdrv_p1.xml "$BACKUP_DIR/" 2>/dev/null
    fi

    if [ -x "$SERVICE_LINK" ]; then
        "$SERVICE_LINK" stop >/dev/null 2>&1
    fi

    if [ ! -s "$CONFIG" ]; then
        cp "$APP_DIR/toon-mqtt.json" "$CONFIG"
        chmod 600 "$CONFIG"
    fi

    chmod 755 "$APP_DIR/toon_mqtt_client"
    chmod 755 "$APP_DIR/toon-mqtt-service.sh"
    chmod 755 "$APP_DIR/S99toon-mqtt.sh"
    chmod 755 "$APP_DIR/toonmqtt.sh"

    ln -sf "$APP_DIR/toon_mqtt_client" "$BINARY_LINK"
    ln -sf "$APP_DIR/toon-mqtt-service.sh" "$SERVICE_LINK"
    ln -sf "$APP_DIR/S99toon-mqtt.sh" "$BOOT_LINK"

    "$SERVICE_LINK" start
}

uninstall_app() {
    if [ -x "$SERVICE_LINK" ]; then
        "$SERVICE_LINK" stop >/dev/null 2>&1
    fi
    rm -f "$BINARY_LINK" "$SERVICE_LINK" "$BOOT_LINK"
}

case "$1" in
    uninstall) uninstall_app ;;
    *) install_app ;;
esac
