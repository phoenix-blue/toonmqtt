import QtQuick 2.11
import qb.components 1.0

Screen {
    id: root

    screenTitle: "Toon MQTT instellingen"
    isSaveCancelDialog: true
    property int selectedTab: 0

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

                EditTextLabel { id: hostField; width: 450; labelText: "IP / host" }
                EditTextLabel {
                    id: portField
                    width: 450
                    labelText: "Poort"
                    inputHints: Qt.ImhDigitsOnly
                }
                EditTextLabel { id: userField; width: 450; labelText: "Gebruiker" }
                EditTextLabel {
                    id: passwordField
                    width: 450
                    labelText: "Wachtwoord"
                    isPassword: true
                }
                EditTextLabel { id: topicField; width: 450; labelText: "Basistopic" }
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
                }
                EditTextLabel {
                    id: intervalField
                    width: 450
                    labelText: "Publicatie-interval (sec)"
                    inputHints: Qt.ImhDigitsOnly
                }

                SettingToggle {
                    id: discoveryToggle
                    label: "HA automatische configuratie"
                }
                SettingToggle {
                    id: controlToggle
                    label: "Bediening via MQTT"
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

}
