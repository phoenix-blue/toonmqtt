import QtQuick 2.1
import FileIO 1.0
import qb.components 1.0
import qb.base 1.0

App {
    id: toonmqttApp

    property url tileUrl: "ToonmqttTile.qml"
    property url settingsUrl: "ToonmqttSettings.qml"
    property url thumbnailIcon: "qrc:/tsc/refresh.png"

    property string mqttHost: "127.0.0.1"
    property string mqttPort: "1883"
    property string mqttUsername: ""
    property string mqttPassword: ""
    property string baseTopic: "toon/voorbeeld"
    property string platform: "mqtt"
    property string discoveryPrefix: "homeassistant"
    property bool discovery: false
    property bool controlEnabled: true
    property int intervalSeconds: 30
    property bool energyInjection: true
    property int energyTimeoutSeconds: 180

    property bool connected: false
    property bool energyOnline: false
    property string lastPublish: ""
    property string lastEnergyUpdate: ""
    property string lastTest: ""
    property string lastError: ""
    property string testResult: ""

    function init() {
        registry.registerWidget("tile", tileUrl, this, null, {
            thumbLabel: "Toon MQTT",
            thumbIcon: thumbnailIcon,
            thumbCaption: "MQTT",
            thumbCategory: "general",
            thumbWeight: 31,
            baseTileWeight: 11,
            thumbIconVAlignment: "center"
        })
        registry.registerWidget("screen", settingsUrl, this, null, {lazyLoadScreen: true})
    }

    Component.onCompleted: {
        requestInstall()
        loadSettings()
        refreshStatus()
    }

    function requestInstall() {
        var pending = ""
        try { pending = tscCommandFile.read() } catch (e) {}
        if (pending.length === 0)
            tscCommandFile.write("external-toonmqtt")
    }

    function loadSettings() {
        var request = new XMLHttpRequest()
        request.onreadystatechange = function() {
            if (request.readyState === XMLHttpRequest.DONE && request.responseText.length > 0) {
                try {
                    var c = JSON.parse(request.responseText)
                    mqttHost = c.host || mqttHost
                    mqttPort = String(c.port || mqttPort)
                    mqttUsername = c.username !== undefined ? c.username : mqttUsername
                    mqttPassword = c.password !== undefined ? c.password : mqttPassword
                    baseTopic = c.base_topic || baseTopic
                    platform = c.platform || platform
                    discoveryPrefix = c.discovery_prefix || discoveryPrefix
                    discovery = c.discovery !== undefined ? c.discovery : discovery
                    controlEnabled = c.control_enabled !== undefined ? c.control_enabled : controlEnabled
                    intervalSeconds = c.interval_seconds || intervalSeconds
                    energyInjection = c.energy_injection !== undefined ? c.energy_injection : energyInjection
                    energyTimeoutSeconds = c.energy_timeout_seconds || energyTimeoutSeconds
                } catch (e) {
                    lastError = "Instellingen zijn niet leesbaar"
                }
            }
        }
        request.open("GET", "file:///mnt/data/tsc/toon-mqtt.json", true)
        request.send()
    }

    function saveSettings(settings) {
        mqttHost = settings.host
        mqttPort = settings.port
        mqttUsername = settings.username
        mqttPassword = settings.password
        baseTopic = settings.base_topic
        platform = settings.platform
        discoveryPrefix = settings.discovery_prefix
        discovery = settings.discovery
        controlEnabled = settings.control_enabled
        intervalSeconds = settings.interval_seconds
        energyInjection = settings.energy_injection
        energyTimeoutSeconds = settings.energy_timeout_seconds

        var request = new XMLHttpRequest()
        request.open("PUT", "file:///mnt/data/tsc/toon-mqtt.json", false)
        request.send(JSON.stringify({
            host: mqttHost,
            port: parseInt(mqttPort),
            username: mqttUsername,
            password: mqttPassword,
            base_topic: baseTopic,
            platform: platform,
            discovery_prefix: discoveryPrefix,
            discovery: discovery,
            control_enabled: controlEnabled,
            interval_seconds: intervalSeconds,
            energy_injection: energyInjection,
            energy_timeout_seconds: energyTimeoutSeconds
        }, null, "\t"))
        restartService()
    }

    function restartService() {
        testResult = "MQTT wordt opnieuw verbonden..."
        writeControl("reload")
    }

    function testConnection() {
        testResult = "Verbinding testen..."
        writeControl("test")
    }

    function resetEnergyProtection() {
        testResult = "Tellerbeveiliging resetten..."
        writeControl("reset_energy")
    }

    function platformName(value) {
        if (value === "homeassistant")
            return "Home Assistant"
        if (value === "domoticz")
            return "Domoticz"
        if (value === "openhab")
            return "openHAB"
        return "Standaard MQTT"
    }

    function writeControl(command) {
        controlFile.write(command)
    }

    function refreshStatus() {
        try {
            var value = statusFile.read()
            if (value.length === 0)
                return
            var s = JSON.parse(value)
            connected = s.connected === true
            energyOnline = s.energy_online === true
            lastPublish = s.last_publish || ""
            lastEnergyUpdate = s.last_energy_update || ""
            lastTest = s.last_test || ""
            if (s.test_result)
                testResult = s.test_result
            lastError = s.last_error || ""
        } catch (e) {
            connected = false
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: refreshStatus()
    }

    FileIO {
        id: controlFile
        source: "file:///mnt/data/tsc/toon-mqtt-control"
    }

    FileIO {
        id: tscCommandFile
        source: "file:///tmp/tsc.command"
    }

    FileIO {
        id: statusFile
        source: "file:///var/volatile/tmp/toon-mqtt-status.json"
    }

}
