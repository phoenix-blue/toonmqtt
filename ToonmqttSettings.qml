import QtQuick 2.11
import qb.components 1.0

Screen {
    id: root

    screenTitle: "Toon MQTT instellingen"
    isSaveCancelDialog: true
    property int selectedTab: 0
    property int selectedPointGroup: 0
    property string editorKey: ""
    property string editorTitle: ""
    property string editorValue: ""
    property bool editorPassword: false

    function beginEdit(key, title, value, password) {
        editorKey = key
        editorTitle = title
        editorValue = value
        editorPassword = password === true
        editorField.prefilledText = value
        editorPage.visible = true
        openKeyboardTimer.restart()
    }

    function openKeyboard() {
        qkeyboard.open(editorTitle, editorValue, keyboardSaved)
    }

    function keyboardSaved(text) {
        if (text === undefined || text === null)
            return

        editorValue = String(text)
        applyEditorValue(editorKey, editorValue)
        editorPage.visible = false
    }

    function applyEditorValue(key, value) {
        if (key === "host")
            hostField.prefilledText = value
        else if (key === "port")
            portField.prefilledText = value
        else if (key === "username")
            userField.prefilledText = value
        else if (key === "password")
            passwordField.prefilledText = value
        else if (key === "base_topic")
            topicField.prefilledText = value
        else if (key === "discovery_prefix")
            discoveryPrefixField.prefilledText = value
        else if (key === "interval_seconds")
            intervalField.prefilledText = value
        else if (key === "heartbeat_seconds")
            heartbeatField.prefilledText = value
        else if (key === "energy_timeout_seconds")
            energyTimeoutField.prefilledText = value
        else if (key.indexOf("point:") === 0)
            setPointName(key.substring(6), value)
    }

    function setPointName(pointKey, value) {
        for (var i = 0; i < pointRepeater.count; i++) {
            var row = pointRepeater.itemAt(i)
            if (row && row.pointKey === pointKey) {
                row.displayName = value
                return
            }
        }
    }

    function pointRow(pointKey) {
        for (var i = 0; i < pointRepeater.count; i++) {
            var row = pointRepeater.itemAt(i)
            if (row && row.pointKey === pointKey)
                return row
        }
        return null
    }

    function energyRow(pointKey) {
        switch (pointKey) {
        case "inject_power_w": return injectPowerRow
        case "inject_production_w": return injectProductionRow
        case "inject_import_low_kwh": return injectImportLowRow
        case "inject_import_high_kwh": return injectImportHighRow
        case "inject_export_low_kwh": return injectExportLowRow
        case "inject_export_high_kwh": return injectExportHighRow
        case "inject_gas_total_m3": return injectGasRow
        }
        return null
    }

    function setPointWrite(pointKey, enabled) {
        var row = pointRow(pointKey)
        if (row && row.canWrite)
            row.writeEnabled = enabled
    }

    function syncEnergyRow(pointKey, enabled) {
        var row = energyRow(pointKey)
        if (row)
            row.injectionEnabled = enabled
    }

    function syncAllEnergyRows() {
        var keys = ["inject_power_w", "inject_production_w",
                    "inject_import_low_kwh", "inject_import_high_kwh",
                    "inject_export_low_kwh", "inject_export_high_kwh",
                    "inject_gas_total_m3"]
        for (var i = 0; i < keys.length; i++) {
            var row = pointRow(keys[i])
            if (row)
                syncEnergyRow(keys[i], row.writeEnabled)
        }
    }

    function refreshPointRuntime() {
        var statuses = app.pointStatus || {}
        var conflicts = app.sourceConflicts || {}
        for (var i = 0; i < pointRepeater.count; i++) {
            var row = pointRepeater.itemAt(i)
            if (!row)
                continue
            var status = statuses[row.pointKey]
            row.availabilityKnown = status !== undefined
            row.pointAvailable = status !== undefined && status.available === true
            row.sourceText = status !== undefined ? String(status.source || "") : ""
            row.lastSeen = status !== undefined ? String(status.last_seen || "") : ""
            row.warningText = conflicts[row.pointKey] !== undefined ? String(conflicts[row.pointKey]) : ""
        }
    }

    function objectCount(value) {
        var count = 0
        if (!value)
            return count
        for (var key in value)
            count++
        return count
    }

    function availablePointCount() {
        var count = 0
        var statuses = app.pointStatus || {}
        for (var key in statuses) {
            if (statuses[key].available === true)
                count++
        }
        return count
    }

    function loadPointSettings() {
        var configured = app.pointConfig || {}
        for (var i = 0; i < pointRepeater.count; i++) {
            var row = pointRepeater.itemAt(i)
            if (!row)
                continue
            // Always initialise from the catalog first. Older Toon Qt builds do
            // not reliably keep boolean ListModel role bindings on delegates.
            var definition = pointModel.get(i)
            row.publishEnabled = definition.publishDefault === true
            row.writeEnabled = row.canWrite && definition.writeDefault === true
            row.displayName = definition.defaultName
            var point = configured[row.pointKey]
            if (point !== undefined) {
                row.publishEnabled = point.publish === true
                row.writeEnabled = row.canWrite && point.write === true
                if (point.name !== undefined && String(point.name).length > 0)
                    row.displayName = String(point.name)
            }
        }
        syncAllEnergyRows()
        refreshPointRuntime()
    }

    function collectPointSettings() {
        var configured = {}
        for (var i = 0; i < pointRepeater.count; i++) {
            var row = pointRepeater.itemAt(i)
            if (!row)
                continue
            configured[row.pointKey] = {
                publish: row.publishEnabled,
                write: row.canWrite && row.writeEnabled,
                name: row.displayName
            }
        }
        return configured
    }

    function groupKey() {
        return ["thermostat", "sensors", "boiler", "energy", "system"][selectedPointGroup]
    }

    function toggleGroup(propertyName, writableOnly) {
        var group = groupKey()
        var shouldEnable = false
        var i
        for (i = 0; i < pointRepeater.count; i++) {
            var candidate = pointRepeater.itemAt(i)
            if (candidate && candidate.groupKey === group &&
                    (!writableOnly || candidate.canWrite) && !candidate[propertyName]) {
                shouldEnable = true
                break
            }
        }
        for (i = 0; i < pointRepeater.count; i++) {
            var row = pointRepeater.itemAt(i)
            if (row && row.groupKey === group && (!writableOnly || row.canWrite))
                row[propertyName] = shouldEnable
        }
    }

    function resetCurrentGroup() {
        var group = groupKey()
        for (var i = 0; i < pointRepeater.count; i++) {
            var row = pointRepeater.itemAt(i)
            if (!row || row.groupKey !== group)
                continue
            var definition = pointModel.get(i)
            row.publishEnabled = definition.publishDefault
            row.writeEnabled = row.canWrite && definition.writeDefault
            row.displayName = definition.defaultName
        }
    }

    Timer {
        id: openKeyboardTimer
        interval: 150
        repeat: false
        onTriggered: root.openKeyboard()
    }

    Timer {
        id: loadPointSettingsTimer
        interval: 1
        repeat: false
        onTriggered: root.loadPointSettings()
    }

    Component.onCompleted: loadPointSettingsTimer.restart()

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            app.refreshStatus()
            root.refreshPointRuntime()
        }
    }

    Timer {
        id: connectionResultTimer
        interval: 3000
        repeat: false
        onTriggered: {
            app.refreshStatus()
            if (app.connected && app.testResult === "Verbinding testen...")
                app.testResult = "Verbinding geslaagd"
        }
    }

    onShown: {
        hostField.prefilledText = app.mqttHost
        portField.prefilledText = app.mqttPort
        userField.prefilledText = app.mqttUsername
        passwordField.prefilledText = app.mqttPassword
        topicField.prefilledText = app.baseTopic
        platformDropdown.selectValue(app.platform)
        discoveryPrefixField.prefilledText = app.discoveryPrefix
        intervalField.prefilledText = String(app.intervalSeconds)
        heartbeatField.prefilledText = String(app.heartbeatSeconds)
        discoveryToggle.isSwitchedOn = app.discovery
        controlToggle.isSwitchedOn = app.controlEnabled
        energyToggle.isSwitchedOn = app.energyInjection
        energyTimeoutField.prefilledText = String(app.energyTimeoutSeconds)
        loadPointSettingsTimer.restart()
        refreshPointRuntime()
    }

    onSaved: {
        var topic = trimTopic(topicField.inputText)
        var discoveryPrefix = trimTopic(discoveryPrefixField.inputText)
        var port = parseInt(portField.inputText)
        if (isNaN(port) || port < 1 || port > 65535)
            port = 1883
        var interval = parseInt(intervalField.inputText)
        if (isNaN(interval) || interval < 5)
            interval = 30
        var heartbeat = parseInt(heartbeatField.inputText)
        if (isNaN(heartbeat) || heartbeat < 60)
            heartbeat = 300
        var energyTimeout = parseInt(energyTimeoutField.inputText)
        if (isNaN(energyTimeout) || energyTimeout < 30)
            energyTimeout = 180

        app.saveSettings({
            host: hostField.inputText,
            port: String(port),
            username: userField.inputText,
            password: passwordField.inputText,
            base_topic: topic,
            platform: platformDropdown.currentValue,
            discovery_prefix: discoveryPrefix,
            discovery: discoveryToggle.isSwitchedOn,
            control_enabled: controlToggle.isSwitchedOn,
            interval_seconds: interval,
            heartbeat_seconds: heartbeat,
            energy_injection: energyToggle.isSwitchedOn,
            energy_timeout_seconds: energyTimeout,
            points: collectPointSettings()
        })
    }

    function trimTopic(value) {
        var result = value
        while (result.charAt(0) === "/")
            result = result.substring(1)
        while (result.charAt(result.length - 1) === "/")
            result = result.substring(0, result.length - 1)
        return result
    }

    ListModel {
        id: pointModel

        ListElement { pointKey: "climate"; groupKey: "thermostat"; label: "HA thermostaat"; defaultName: "Thermostaat"; publishDefault: true; writeDefault: true; canWrite: true }
        ListElement { pointKey: "current_temperature"; groupKey: "thermostat"; label: "Kamertemperatuur"; defaultName: "Kamertemperatuur"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "setpoint"; groupKey: "thermostat"; label: "Gewenste temperatuur"; defaultName: "Gewenste temperatuur"; publishDefault: true; writeDefault: true; canWrite: true }
        ListElement { pointKey: "program"; groupKey: "thermostat"; label: "Weekprogramma"; defaultName: "Weekprogramma"; publishDefault: true; writeDefault: true; canWrite: true }
        ListElement { pointKey: "preset"; groupKey: "thermostat"; label: "Temperatuurstand"; defaultName: "Temperatuurstand"; publishDefault: true; writeDefault: true; canWrite: true }
        ListElement { pointKey: "hvac_action"; groupKey: "thermostat"; label: "Verwarmingsactie"; defaultName: "Verwarmingsactie"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "burner"; groupKey: "thermostat"; label: "Branderstatus"; defaultName: "Branderstatus"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "burner_active"; groupKey: "thermostat"; label: "Brander actief"; defaultName: "Brander actief"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "modulation_percent"; groupKey: "thermostat"; label: "Ketelmodulatie"; defaultName: "Ketelmodulatie"; publishDefault: true; writeDefault: false; canWrite: false }

        ListElement { pointKey: "humidity"; groupKey: "sensors"; label: "Gecorrigeerde luchtvochtigheid"; defaultName: "Luchtvochtigheid"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "primary_temperature"; groupKey: "sensors"; label: "Ruwe ENS210-temperatuur"; defaultName: "Ruwe sensortemperatuur"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "primary_humidity"; groupKey: "sensors"; label: "Ruwe ENS210-luchtvochtigheid"; defaultName: "Ruwe sensorluchtvochtigheid"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "tvoc_ppb"; groupKey: "sensors"; label: "TVOC"; defaultName: "TVOC"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "eco2_ppm"; groupKey: "sensors"; label: "Geschatte CO₂"; defaultName: "Geschatte CO₂"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "light_intensity"; groupKey: "sensors"; label: "Omgevingslicht (ruwe telling)"; defaultName: "Omgevingslicht (ruw)"; publishDefault: true; writeDefault: false; canWrite: false }

        ListElement { pointKey: "internal_boiler_setpoint"; groupKey: "boiler"; label: "Ketel-doeltemperatuur"; defaultName: "Ketel-doeltemperatuur"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "dhw_active"; groupKey: "boiler"; label: "Tapwater actief"; defaultName: "Tapwater actief"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "dhw_enabled"; groupKey: "boiler"; label: "Tapwater voorverwarmen"; defaultName: "Tapwater voorverwarmen"; publishDefault: true; writeDefault: true; canWrite: true }
        ListElement { pointKey: "dhw_setpoint"; groupKey: "boiler"; label: "Tapwatertemperatuur"; defaultName: "Tapwatertemperatuur"; publishDefault: true; writeDefault: true; canWrite: true }
        ListElement { pointKey: "max_heater_temperature"; groupKey: "boiler"; label: "Maximale cv-temperatuur"; defaultName: "Maximale cv-temperatuur"; publishDefault: true; writeDefault: true; canWrite: true }
        ListElement { pointKey: "max_heating_rate"; groupKey: "boiler"; label: "Maximaal cv-vermogen"; defaultName: "Maximaal cv-vermogen"; publishDefault: true; writeDefault: true; canWrite: true }
        ListElement { pointKey: "temperature_offset"; groupKey: "boiler"; label: "Temperatuurcorrectie"; defaultName: "Temperatuurcorrectie"; publishDefault: true; writeDefault: true; canWrite: true }
        ListElement { pointKey: "boiler_flow_temperature"; groupKey: "boiler"; label: "OpenTherm aanvoertemperatuur"; defaultName: "Ketel aanvoertemperatuur"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "boiler_return_temperature"; groupKey: "boiler"; label: "OpenTherm retourtemperatuur"; defaultName: "Ketel retourtemperatuur"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "boiler_pressure_bar"; groupKey: "boiler"; label: "Cv-waterdruk"; defaultName: "Cv-waterdruk"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "dhw_temperature"; groupKey: "boiler"; label: "Tapwatertemperatuur actueel"; defaultName: "Tapwatertemperatuur actueel"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "dhw_flow_rate_lpm"; groupKey: "boiler"; label: "Tapwaterdebiet"; defaultName: "Tapwaterdebiet"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "outside_temperature"; groupKey: "boiler"; label: "OpenTherm buitentemperatuur"; defaultName: "OpenTherm buitentemperatuur"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "boiler_exhaust_temperature"; groupKey: "boiler"; label: "Rookgastemperatuur"; defaultName: "Ketel rookgastemperatuur"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "max_boiler_capacity_kw"; groupKey: "boiler"; label: "Ketelcapaciteit"; defaultName: "Ketelcapaciteit"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "min_modulation_level_percent"; groupKey: "boiler"; label: "Minimaal modulatieniveau"; defaultName: "Minimaal modulatieniveau"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "burner_starts"; groupKey: "boiler"; label: "Aantal branderstarts"; defaultName: "Aantal branderstarts"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "ch_pump_starts"; groupKey: "boiler"; label: "Aantal cv-pompstarts"; defaultName: "Aantal cv-pompstarts"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "dhw_pump_starts"; groupKey: "boiler"; label: "Aantal tapwaterpompstarts"; defaultName: "Aantal tapwaterpompstarts"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "dhw_burner_starts"; groupKey: "boiler"; label: "Aantal tapwaterbranderstarts"; defaultName: "Aantal tapwaterbranderstarts"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "burner_hours"; groupKey: "boiler"; label: "Branderuren"; defaultName: "Branderuren"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "ch_pump_hours"; groupKey: "boiler"; label: "Cv-pompuren"; defaultName: "Cv-pompuren"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "dhw_pump_hours"; groupKey: "boiler"; label: "Tapwaterpompuren"; defaultName: "Tapwaterpompuren"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "dhw_burner_hours"; groupKey: "boiler"; label: "Tapwaterbranderuren"; defaultName: "Tapwaterbranderuren"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "opentherm_slave_version"; groupKey: "boiler"; label: "OpenTherm ketelversie"; defaultName: "OpenTherm ketelversie"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "opentherm_oem_diagnostic_code"; groupKey: "boiler"; label: "OpenTherm diagnosecode"; defaultName: "OpenTherm diagnosecode"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "opentherm_communication_error"; groupKey: "boiler"; label: "OpenTherm communicatiefout"; defaultName: "OpenTherm communicatiefout"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "thermostat_connection"; groupKey: "boiler"; label: "Thermostaatverbinding (ruw)"; defaultName: "Thermostaatverbinding (ruw)"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "error_code"; groupKey: "boiler"; label: "Thermostaat foutcode (ruw)"; defaultName: "Thermostaat foutcode (ruw)"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "heating_type"; groupKey: "boiler"; label: "Verwarmingstype (ruw)"; defaultName: "Verwarmingstype (ruw)"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "heater_fuel_type"; groupKey: "boiler"; label: "Brandstoftype"; defaultName: "Brandstoftype"; publishDefault: true; writeDefault: false; canWrite: false }

        ListElement { pointKey: "power_usage_w"; groupKey: "energy"; label: "Elektriciteitsverbruik"; defaultName: "Elektriciteitsverbruik"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "power_usage_average_w"; groupKey: "energy"; label: "Verbruik gemiddeld"; defaultName: "Elektriciteitsverbruik gemiddeld"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "power_production_w"; groupKey: "energy"; label: "Elektriciteitsproductie"; defaultName: "Elektriciteitsproductie"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "power_production_average_w"; groupKey: "energy"; label: "Productie gemiddeld"; defaultName: "Elektriciteitsproductie gemiddeld"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "gas_usage_lph"; groupKey: "energy"; label: "Gasdebiet"; defaultName: "Gasdebiet"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "gas_usage_average_lph"; groupKey: "energy"; label: "Gasdebiet gemiddeld"; defaultName: "Gasdebiet gemiddeld"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "inject_power_w"; groupKey: "energy"; label: "Injectie huidig verbruik"; defaultName: "Injectie huidig verbruik"; publishDefault: true; writeDefault: true; canWrite: true }
        ListElement { pointKey: "inject_production_w"; groupKey: "energy"; label: "Injectie teruglevering"; defaultName: "Injectie huidige teruglevering"; publishDefault: true; writeDefault: true; canWrite: true }
        ListElement { pointKey: "inject_import_low_kwh"; groupKey: "energy"; label: "Injectie verbruik laag"; defaultName: "Injectie verbruik laag tarief"; publishDefault: true; writeDefault: true; canWrite: true }
        ListElement { pointKey: "inject_import_high_kwh"; groupKey: "energy"; label: "Injectie verbruik hoog"; defaultName: "Injectie verbruik hoog tarief"; publishDefault: true; writeDefault: true; canWrite: true }
        ListElement { pointKey: "inject_export_low_kwh"; groupKey: "energy"; label: "Injectie terug laag"; defaultName: "Injectie teruglevering laag tarief"; publishDefault: true; writeDefault: true; canWrite: true }
        ListElement { pointKey: "inject_export_high_kwh"; groupKey: "energy"; label: "Injectie terug hoog"; defaultName: "Injectie teruglevering hoog tarief"; publishDefault: true; writeDefault: true; canWrite: true }
        ListElement { pointKey: "inject_gas_total_m3"; groupKey: "energy"; label: "Injectie gasmeterstand"; defaultName: "Injectie gasmeterstand"; publishDefault: true; writeDefault: true; canWrite: true }

        ListElement { pointKey: "system_cpu_percent"; groupKey: "system"; label: "CPU-belasting"; defaultName: "CPU-belasting"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "system_load_1m"; groupKey: "system"; label: "Systeembelasting 1 minuut"; defaultName: "Systeembelasting 1 minuut"; publishDefault: false; writeDefault: false; canWrite: false }
        ListElement { pointKey: "system_memory_percent"; groupKey: "system"; label: "Geheugengebruik"; defaultName: "Geheugengebruik"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "system_memory_available_mb"; groupKey: "system"; label: "Beschikbaar geheugen"; defaultName: "Beschikbaar geheugen"; publishDefault: false; writeDefault: false; canWrite: false }
        ListElement { pointKey: "system_temperature_c"; groupKey: "system"; label: "Processortemperatuur"; defaultName: "Toon processortemperatuur"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "system_uptime_hours"; groupKey: "system"; label: "Uptime"; defaultName: "Toon uptime"; publishDefault: true; writeDefault: false; canWrite: false }
        ListElement { pointKey: "system_root_storage_percent"; groupKey: "system"; label: "Opslaggebruik systeem"; defaultName: "Opslaggebruik systeem"; publishDefault: false; writeDefault: false; canWrite: false }
        ListElement { pointKey: "system_data_storage_percent"; groupKey: "system"; label: "Opslaggebruik gegevens"; defaultName: "Opslaggebruik gegevens"; publishDefault: false; writeDefault: false; canWrite: false }
        ListElement { pointKey: "system_wifi_received_mb"; groupKey: "system"; label: "WiFi ontvangen"; defaultName: "WiFi ontvangen"; publishDefault: false; writeDefault: false; canWrite: false }
        ListElement { pointKey: "system_wifi_transmitted_mb"; groupKey: "system"; label: "WiFi verzonden"; defaultName: "WiFi verzonden"; publishDefault: false; writeDefault: false; canWrite: false }
    }

    Row {
        id: tabs
        anchors {
            top: parent.top
            topMargin: 8
            horizontalCenter: parent.horizontalCenter
        }
        spacing: 8

        TabButton {
            text: "Broker"
            width: 220
            height: 40
            active: root.selectedTab === 0
            onClicked: root.selectedTab = 0
        }

        TabButton {
            text: "Energie naar Toon"
            width: 220
            height: 40
            active: root.selectedTab === 1
            onClicked: root.selectedTab = 1
        }


        TabButton {
            text: "Datapunten"
            width: 220
            height: 40
            active: root.selectedTab === 2
            onClicked: root.selectedTab = 2
        }

        TabButton {
            text: "Status & diagnose"
            width: 220
            height: 40
            active: root.selectedTab === 3
            onClicked: root.selectedTab = 3
        }
    }

    Item {
        id: connectionPage
        visible: root.selectedTab === 0
        anchors {
            top: tabs.bottom
            topMargin: 14
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 28

            Column {
                spacing: 8

                Text {
                    text: "MQTT broker"
                    color: colors.clockTileSelectedColor
                    font {
                        family: qfont.semiBold.name
                        pixelSize: qfont.navigationTitle
                    }
                }

                EditTextLabel {
                    id: hostField
                    width: 450
                    labelText: "IP / host"
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.beginEdit("host", hostField.labelText,
                                                  hostField.inputText, false)
                    }
                }
                EditTextLabel {
                    id: portField
                    width: 450
                    labelText: "Poort"
                    inputHints: Qt.ImhDigitsOnly
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.beginEdit("port", portField.labelText,
                                                  portField.inputText, false)
                    }
                }
                EditTextLabel {
                    id: userField
                    width: 450
                    labelText: "Gebruiker"
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.beginEdit("username", userField.labelText,
                                                  userField.inputText, false)
                    }
                }
                EditTextLabel {
                    id: passwordField
                    width: 450
                    labelText: "Wachtwoord"
                    isPassword: true
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.beginEdit("password", passwordField.labelText,
                                                  passwordField.inputText, true)
                    }
                }
                EditTextLabel {
                    id: topicField
                    width: 450
                    labelText: "Basistopic"
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.beginEdit("base_topic", topicField.labelText,
                                                  topicField.inputText, false)
                    }
                }
            }

            Column {
                spacing: 8

                Text {
                    text: "Integratie"
                    color: colors.clockTileSelectedColor
                    font {
                        family: qfont.semiBold.name
                        pixelSize: qfont.navigationTitle
                    }
                }

                PlatformDropdown { id: platformDropdown }
                EditTextLabel {
                    id: discoveryPrefixField
                    width: 450
                    labelText: "Discovery-prefix"
                    placeholder: "homeassistant"
                    visible: platformDropdown.currentValue === "homeassistant"
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.beginEdit("discovery_prefix",
                                                  discoveryPrefixField.labelText,
                                                  discoveryPrefixField.inputText, false)
                    }
                }
                EditTextLabel {
                    id: intervalField
                    width: 450
                    labelText: "Meetinterval (sec)"
                    inputHints: Qt.ImhDigitsOnly
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.beginEdit("interval_seconds",
                                                  intervalField.labelText,
                                                  intervalField.inputText, false)
                    }
                }
                EditTextLabel {
                    id: heartbeatField
                    width: 450
                    labelText: "Volledige heartbeat (sec)"
                    inputHints: Qt.ImhDigitsOnly
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.beginEdit("heartbeat_seconds",
                                                  heartbeatField.labelText,
                                                  heartbeatField.inputText, false)
                    }
                }

                SettingToggle {
                    id: discoveryToggle
                    label: "HA automatische configuratie"
                    visible: platformDropdown.currentValue === "homeassistant"
                }
                SettingToggle {
                    id: controlToggle
                    label: "Bediening via MQTT"
                }

                Text {
                    width: 430
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    visible: platformDropdown.currentValue !== "homeassistant"
                    text: platformDropdown.currentValue === "mqtt" ?
                          "Basisprofiel: gewone MQTT-topics, zonder domotica-afhankelijke configuratie." :
                          "Dit profiel gebruikt de gewone MQTT-topics. Systeemspecifieke instellingen verschijnen alleen wanneer ze nodig zijn."
                    color: "#555555"
                    font.pixelSize: qfont.metaText
                }

                StandardButton {
                    text: "Test verbinding"
                    width: 220
                    height: 42
                    anchors.horizontalCenter: parent.horizontalCenter
                    onClicked: {
                        app.testConnection()
                        connectionResultTimer.restart()
                    }
                }

                Text {
                    width: 430
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: app.testResult.length > 0 ? app.testResult :
                          (app.connected ? "MQTT verbonden" :
                           "Niet verbonden" + (app.lastError ? ": " + app.lastError : ""))
                    color: app.connected ? "#1c7a46" : "#a63b32"
                    font.pixelSize: qfont.metaText
                }
            }
        }
    }

    Item {
        id: energyPage
        visible: root.selectedTab === 1
        anchors {
            top: tabs.bottom
            topMargin: 14
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Text {
                width: 920
                text: "Vink alleen de waarden aan die MQTT in Toon mag invoeren. Uitgevinkte waarden en hun timeout-nulstelling raken bestaande Toon-apps niet. Tellerstanden zijn kWh en m³; actuele waarden zijn Watt."
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: "#333333"
                font.pixelSize: qfont.bodyText
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 28

                SettingToggle {
                    id: energyToggle
                    width: 440
                    label: "Energie-injectie"
                }

                EditTextLabel {
                    id: energyTimeoutField
                    width: 440
                    labelText: "Live-data timeout (sec)"
                    inputHints: Qt.ImhDigitsOnly
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.beginEdit("energy_timeout_seconds",
                                                  energyTimeoutField.labelText,
                                                  energyTimeoutField.inputText, false)
                    }
                }
            }

            Rectangle {
                width: 920
                height: 278
                radius: 4
                color: "#f5f5f5"
                border.color: "#c8c8c8"

                Column {
                    anchors {
                        fill: parent
                        margins: 14
                    }
                    spacing: 8

                    EnergyTopicRow {
                        id: injectPowerRow
                        title: "Actueel verbruik"; pointKey: "inject_power_w"; suffix: "inject/power_w"; unit: "W"
                        masterEnabled: energyToggle.isSwitchedOn
                        onInjectionToggled: root.setPointWrite(pointKey, selected)
                    }
                    EnergyTopicRow {
                        id: injectProductionRow
                        title: "Teruglevering"; pointKey: "inject_production_w"; suffix: "inject/production_w"; unit: "W"
                        masterEnabled: energyToggle.isSwitchedOn
                        onInjectionToggled: root.setPointWrite(pointKey, selected)
                    }
                    EnergyTopicRow {
                        id: injectImportLowRow
                        title: "Verbruik laag"; pointKey: "inject_import_low_kwh"; suffix: "inject/import_low_kwh"; unit: "kWh"
                        masterEnabled: energyToggle.isSwitchedOn
                        onInjectionToggled: root.setPointWrite(pointKey, selected)
                    }
                    EnergyTopicRow {
                        id: injectImportHighRow
                        title: "Verbruik hoog"; pointKey: "inject_import_high_kwh"; suffix: "inject/import_high_kwh"; unit: "kWh"
                        masterEnabled: energyToggle.isSwitchedOn
                        onInjectionToggled: root.setPointWrite(pointKey, selected)
                    }
                    EnergyTopicRow {
                        id: injectExportLowRow
                        title: "Terug laag"; pointKey: "inject_export_low_kwh"; suffix: "inject/export_low_kwh"; unit: "kWh"
                        masterEnabled: energyToggle.isSwitchedOn
                        onInjectionToggled: root.setPointWrite(pointKey, selected)
                    }
                    EnergyTopicRow {
                        id: injectExportHighRow
                        title: "Terug hoog"; pointKey: "inject_export_high_kwh"; suffix: "inject/export_high_kwh"; unit: "kWh"
                        masterEnabled: energyToggle.isSwitchedOn
                        onInjectionToggled: root.setPointWrite(pointKey, selected)
                    }
                    EnergyTopicRow {
                        id: injectGasRow
                        title: "Gasmeterstand"; pointKey: "inject_gas_total_m3"; suffix: "inject/gas_total_m3"; unit: "m³"
                        masterEnabled: energyToggle.isSwitchedOn
                        onInjectionToggled: root.setPointWrite(pointKey, selected)
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 24

                StandardButton {
                    text: "Tellerbeveiliging resetten"
                    width: 290
                    height: 42
                    onClicked: app.resetEnergyProtection()
                }

                Text {
                    width: 500
                    anchors.verticalCenter: parent.verticalCenter
                    text: app.energyOnline ? "Energiedata wordt ontvangen" :
                          "Nog geen actuele energiedata ontvangen"
                    color: app.energyOnline ? "#1c7a46" : "#a66a22"
                    font.pixelSize: qfont.metaText
                }
            }
        }
    }

    Item {
        id: pointPage
        visible: root.selectedTab === 2
        anchors {
            top: tabs.bottom
            topMargin: 8
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        Row {
            id: pointTabs
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            TabButton { text: "Thermostaat"; width: 178; height: 38; active: root.selectedPointGroup === 0; onClicked: root.selectedPointGroup = 0 }
            TabButton { text: "BXT-sensoren"; width: 178; height: 38; active: root.selectedPointGroup === 1; onClicked: root.selectedPointGroup = 1 }
            TabButton { text: "Ketel / OT"; width: 178; height: 38; active: root.selectedPointGroup === 2; onClicked: root.selectedPointGroup = 2 }
            TabButton { text: "Energie"; width: 178; height: 38; active: root.selectedPointGroup === 3; onClicked: root.selectedPointGroup = 3 }
            TabButton { text: "Toon hardware"; width: 178; height: 38; active: root.selectedPointGroup === 4; onClicked: root.selectedPointGroup = 4 }
        }

        Row {
            id: pointActions
            anchors {
                top: pointTabs.bottom
                topMargin: 5
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 10

            StandardButton {
                text: "Alle leesvinkjes"
                width: 210
                height: 34
                onClicked: root.toggleGroup("publishEnabled", false)
            }
            StandardButton {
                text: "Alle schrijfvinkjes"
                width: 220
                height: 34
                onClicked: root.toggleGroup("writeEnabled", true)
            }
            StandardButton {
                text: "Herstel standaard"
                width: 210
                height: 34
                onClicked: root.resetCurrentGroup()
            }
        }

        Rectangle {
            id: pointHeader
            anchors {
                top: pointActions.bottom
                topMargin: 5
                horizontalCenter: parent.horizontalCenter
            }
            width: 930
            height: 34
            color: "#d9d9d9"
            border.color: "#bbbbbb"

            Text { x: 12; width: 300; anchors.verticalCenter: parent.verticalCenter; text: "Datapunt"; font.bold: true; font.pixelSize: qfont.metaText }
            Text { x: 326; width: 70; anchors.verticalCenter: parent.verticalCenter; text: "Lezen"; horizontalAlignment: Text.AlignHCenter; font.bold: true; font.pixelSize: qfont.metaText }
            Text { x: 425; width: 70; anchors.verticalCenter: parent.verticalCenter; text: "Schrijven"; horizontalAlignment: Text.AlignHCenter; font.bold: true; font.pixelSize: qfont.metaText }
            Text { x: 525; width: 380; anchors.verticalCenter: parent.verticalCenter; text: "Naam in domoticasysteem"; font.bold: true; font.pixelSize: qfont.metaText }
        }

        Flickable {
            id: pointList
            anchors {
                top: pointHeader.bottom
                topMargin: 2
                bottom: parent.bottom
                bottomMargin: 4
                horizontalCenter: parent.horizontalCenter
            }
            width: 930
            clip: true
            contentWidth: width
            contentHeight: pointColumn.height

            Column {
                id: pointColumn
                width: parent.width
                spacing: 1

                Repeater {
                    id: pointRepeater
                    model: pointModel

                    PointSettingRow {
                        rowIndex: index
                        pointKey: model.pointKey
                        groupKey: model.groupKey
                        labelText: model.label
                        displayName: model.defaultName
                        publishEnabled: model.publishDefault
                        writeEnabled: model.writeDefault
                        canWrite: model.canWrite
                        availabilityKnown: false
                        pointAvailable: true
                        onWriteEnabledChanged: root.syncEnergyRow(pointKey, writeEnabled)
                        visible: groupKey === root.groupKey()
                        height: visible ? 52 : 0
                        onEditNameRequested: root.beginEdit("point:" + pointKey,
                                                           title, value, false)
                    }
                }
            }
        }
    }

    Item {
        id: statusPage
        visible: root.selectedTab === 3
        anchors {
            top: tabs.bottom
            topMargin: 16
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Text {
                width: 900
                text: "MQTT-status en veilige diagnose"
                horizontalAlignment: Text.AlignHCenter
                color: colors.clockTileSelectedColor
                font {
                    family: qfont.semiBold.name
                    pixelSize: qfont.navigationTitle
                }
            }

            Rectangle {
                width: 900
                height: 170
                radius: 4
                color: "#f5f5f5"
                border.color: "#c8c8c8"

                Column {
                    anchors { fill: parent; margins: 16 }
                    spacing: 8

                    Text { text: "MQTT: " + (app.connected ? "verbonden" : "niet verbonden"); color: app.connected ? "#1c7a46" : "#a63b32"; font.pixelSize: qfont.bodyText }
                    Text { text: "Beschikbare datapunten: " + root.availablePointCount(); color: "#333333"; font.pixelSize: qfont.bodyText }
                    Text { text: "Bronconflicten: " + root.objectCount(app.sourceConflicts); color: root.objectCount(app.sourceConflicts) > 0 ? "#a66a22" : "#1c7a46"; font.pixelSize: qfont.bodyText }
                    Text { text: "Laatste meting: " + (app.lastSample || "nog niet"); color: "#333333"; font.pixelSize: qfont.metaText }
                    Text { text: "Laatste MQTT-publicatie: " + (app.lastPublish || "nog niet"); color: "#333333"; font.pixelSize: qfont.metaText }
                    Text { text: "Laatste gebeurtenis: " + (app.lastEventType || "geen"); color: "#333333"; font.pixelSize: qfont.metaText }
                }
            }

            Text {
                width: 880
                text: root.objectCount(app.sourceConflicts) > 0 ?
                      "Let op: er lijkt minimaal één energiepunt ook door een andere Toon-bron te worden bijgewerkt. Bekijk de waarschuwing bij Datapunten → Energie." :
                      "Geen actieve bronconflicten gedetecteerd."
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: root.objectCount(app.sourceConflicts) > 0 ? "#a66a22" : "#1c7a46"
                font.pixelSize: qfont.bodyText
            }

            StandardButton {
                text: "Maak veilig diagnoserapport"
                width: 340
                height: 44
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: app.exportDiagnostics()
            }

            Text {
                width: 880
                text: app.testResult.length > 0 ? app.testResult :
                      "Het rapport bevat geen brokeradres, account, wachtwoord, topics, meetwaarden of aangepaste namen."
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: "#555555"
                font.pixelSize: qfont.metaText
            }

            Text {
                width: 880
                visible: app.lastError.length > 0
                text: "Laatste fout: " + app.lastError
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: "#a63b32"
                font.pixelSize: qfont.metaText
            }
        }
    }

    Rectangle {
        id: editorPage
        anchors.fill: parent
        visible: false
        z: 1000
        color: "#f2f2f2"

        Column {
            anchors {
                top: parent.top
                topMargin: 24
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 14

            Text {
                width: 760
                text: "Bewerk " + root.editorTitle
                horizontalAlignment: Text.AlignHCenter
                color: colors.clockTileSelectedColor
                font {
                    family: qfont.semiBold.name
                    pixelSize: qfont.navigationTitle
                }
            }

            EditTextLabel {
                id: editorField
                width: 760
                labelText: root.editorTitle
                isPassword: root.editorPassword

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.openKeyboard()
                }
            }

            Text {
                width: 760
                text: "De invoer staat boven het schermtoetsenbord. Kies Opslaan op het toetsenbord om de waarde over te nemen."
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: "#555555"
                font.pixelSize: qfont.metaText
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18

                StandardButton {
                    text: "Toetsenbord openen"
                    width: 260
                    height: 42
                    onClicked: root.openKeyboard()
                }

                StandardButton {
                    text: "Annuleren"
                    width: 180
                    height: 42
                    onClicked: editorPage.visible = false
                }
            }
        }
    }

}
