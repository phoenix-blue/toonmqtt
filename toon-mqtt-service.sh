#!/bin/sh

BIN=/qmf/qml/apps/toonmqtt/toon_mqtt_client
PID=/var/run/toon-mqtt.pid
LOG=/var/volatile/log/toon-mqtt.log
CONFIG=/mnt/data/tsc/toon-mqtt.json

is_running() {
    test -f "$PID" && kill -0 "$(cat "$PID")" 2>/dev/null
}

start_service() {
    if test ! -x "$BIN"; then
        exit 1
    fi
    if is_running; then
        exit 0
    fi
    mkdir -p /var/volatile/log
    "$BIN" -config "$CONFIG" >>"$LOG" 2>&1 &
    echo $! >"$PID"
}

stop_service() {
    if is_running; then
        kill "$(cat "$PID")" 2>/dev/null
        i=0
        while is_running && test "$i" -lt 20; do
            usleep 100000 2>/dev/null || sleep 1
            i=$((i + 1))
        done
    fi
    if test -f "$PID"; then
        mv "$PID" "$PID.stopped"
    fi
}

case "$1" in
    start) start_service ;;
    stop) stop_service ;;
    restart) stop_service; start_service ;;
    status)
        if is_running; then
            echo running
        else
            echo stopped
            exit 1
        fi
        ;;
    test) "$BIN" -config "$CONFIG" -probe ;;
    *) echo "Gebruik: $0 {start|stop|restart|status|test}"; exit 2 ;;
esac
