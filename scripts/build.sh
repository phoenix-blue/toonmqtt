#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

cd "$PROJECT_DIR/daemon"
gofmt -w main.go
go test ./...
CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 \
    go build -buildvcs=false -trimpath -ldflags="-s -w" \
    -o "$PROJECT_DIR/toon_mqtt_client" .
chmod 755 "$PROJECT_DIR/toon_mqtt_client"
sha256sum "$PROJECT_DIR/toon_mqtt_client" 2>/dev/null ||
    shasum -a 256 "$PROJECT_DIR/toon_mqtt_client"
