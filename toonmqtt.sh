#!/bin/sh

# Wordt automatisch uitgevoerd door het bestaande TSC-hulpscript wanneer
# ToonmqttApp.qml "external-toonmqtt" naar /tmp/tsc.command schrijft.

APP_DIR=/qmf/qml/apps/toonmqtt
CONFIG=/mnt/data/tsc/toon-mqtt.json
BACKUP_DIR=/mnt/data/tsc/backups/toonmqtt-energy-original
SERVICE_LINK=/qmf/bin/toon-mqtt-service.sh
BINARY_LINK=/qmf/bin/toon_mqtt_client
BOOT_LINK=/etc/rc5.d/S99toon-mqtt
STATUS=/var/volatile/tmp/toon-mqtt-status.json
CONTROL=/mnt/data/tsc/toon-mqtt-control
ENERGY_STATE=/mnt/data/tsc/toon-mqtt-energy.json
PID=/var/run/toon-mqtt.pid
STOPPED_PID=/var/run/toon-mqtt.pid.stopped
LOG=/var/volatile/log/toon-mqtt.log

install_app() {
    mkdir -p /mnt/data/tsc /var/volatile/log

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
    elif [ -x "$APP_DIR/toon-mqtt-service.sh" ]; then
        "$APP_DIR/toon-mqtt-service.sh" stop >/dev/null 2>&1
    fi
    rm -f "$BINARY_LINK" "$SERVICE_LINK" "$BOOT_LINK" \
        "$STATUS" "$CONTROL" "$ENERGY_STATE" "$CONFIG" \
        "$PID" "$STOPPED_PID" "$LOG"
    rm -rf "$BACKUP_DIR"
}

case "$1" in
    uninstall) uninstall_app ;;
    *) install_app ;;
esac
