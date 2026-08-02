import QtQuick 2.11
import qb.components 1.0

Screen {
    id: root

    screenTitle: "Toon MQTT instellingen"
    isSaveCancelDialog: true
    property int selectedTab: 0
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
        else if (key === "energy_timeout_seconds")
            energyTimeoutField.prefilledText = value
    }

    Timer {
        id: openKeyboardTimer
        interval: 150
        repeat: false
        onTriggered: root.openKeyboard()
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: app.refreshStatus()
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
        discoveryToggle.isSwitchedOn = app.discovery
        controlToggle.isSwitchedOn = app.controlEnabled
        energyToggle.isSwitchedOn = app.energyInjection
        energyTimeoutField.prefilledText = String(app.energyTimeoutSeconds)
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
            energy_injection: energyToggle.isSwitchedOn,
            energy_timeout_seconds: energyTimeout
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

    Row {
        id: tabs
        anchors {
            top: parent.top
            topMargin: 8
            horizontalCenter: parent.horizontalCenter
        }
        spacing: 8

        StandardButton {
            text: "Broker en integratie"
            width: 250
            height: 40
            onClicked: root.selectedTab = 0
        }

        StandardButton {
            text: "Energie naar Toon"
            width: 250
            height: 40
            onClicked: root.selectedTab = 1
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
                    labelText: "Publicatie-interval (sec)"
                    inputHints: Qt.ImhDigitsOnly
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.beginEdit("interval_seconds",
                                                  intervalField.labelText,
                                                  intervalField.inputText, false)
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
                text: "Deze topics ontvangen waarden uit je domoticasysteem en voeren ze als normale Toon-meterdata in. Tellerstanden zijn kWh en m³; actuele waarden zijn Watt."
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

                    EnergyTopicRow { title: "Actueel verbruik"; suffix: "inject/power_w"; unit: "W" }
                    EnergyTopicRow { title: "Teruglevering"; suffix: "inject/production_w"; unit: "W" }
                    EnergyTopicRow { title: "Verbruik laag"; suffix: "inject/import_low_kwh"; unit: "kWh" }
                    EnergyTopicRow { title: "Verbruik hoog"; suffix: "inject/import_high_kwh"; unit: "kWh" }
                    EnergyTopicRow { title: "Terug laag"; suffix: "inject/export_low_kwh"; unit: "kWh" }
                    EnergyTopicRow { title: "Terug hoog"; suffix: "inject/export_high_kwh"; unit: "kWh" }
                    EnergyTopicRow { title: "Gasmeterstand"; suffix: "inject/gas_total_m3"; unit: "m³" }
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
