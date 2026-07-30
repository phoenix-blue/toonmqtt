import QtQuick 2.1
import qb.components 1.0

Item {
    id: root
    width: 450
    height: 54
    z: popup.visible ? 1000 : 1

    property string currentValue: "homeassistant"
    property string currentLabel: "Home Assistant"

    function selectValue(value) {
        for (var i = 0; i < platformModel.count; i++) {
            if (platformModel.get(i).value === value) {
                currentValue = value
                currentLabel = platformModel.get(i).label
                return
            }
        }
        currentValue = "mqtt"
        currentLabel = "Standaard MQTT"
    }

    Text {
        text: "Domoticasysteem"
        color: "#555555"
        font.pixelSize: qfont.metaText
        anchors {
            left: parent.left
            top: parent.top
        }
    }

    StandardButton {
        id: selector
        height: 34
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        text: root.currentLabel + (popup.visible ? "  \u25b2" : "  \u25bc")
        onClicked: popup.visible = !popup.visible
    }

    Rectangle {
        id: popup
        visible: false
        z: 1001
        width: selector.width
        height: platformModel.count * 40
        anchors {
            top: selector.bottom
            left: selector.left
        }
        color: "white"
        border.color: colors.clockTileSelectedColor
        border.width: 1

        Column {
            anchors.fill: parent

            Repeater {
                model: platformModel

                StandardButton {
                    width: popup.width
                    height: 40
                    text: label
                    onClicked: {
                        root.currentValue = value
                        root.currentLabel = label
                        popup.visible = false
                    }
                }
            }
        }
    }

    ListModel {
        id: platformModel
        ListElement { label: "Standaard MQTT"; value: "mqtt" }
        ListElement { label: "Home Assistant"; value: "homeassistant" }
        ListElement { label: "Domoticz"; value: "domoticz" }
        ListElement { label: "openHAB"; value: "openhab" }
    }
}
