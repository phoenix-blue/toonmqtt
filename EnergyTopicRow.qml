import QtQuick 2.1
import qb.components 1.0

Item {
    id: root
    width: parent ? parent.width : 890
    height: 31

    property string title: ""
    property string suffix: ""
    property string unit: ""
    property string pointKey: ""
    property bool injectionEnabled: true
    property bool masterEnabled: true

    signal injectionToggled(string pointKey, bool selected)

    Text {
        text: root.title
        width: 170
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        color: "#333333"
        font.pixelSize: qfont.metaText
    }

    Rectangle {
        id: injectionBox
        width: 26
        height: 26
        anchors {
            left: parent.left
            leftMargin: 172
            verticalCenter: parent.verticalCenter
        }
        radius: 3
        color: root.injectionEnabled ? "#6f2c91" : "#ffffff"
        border.color: root.injectionEnabled ? "#6f2c91" : "#777777"
        border.width: 2
        opacity: root.masterEnabled ? 1 : 0.4

        Text {
            anchors.centerIn: parent
            text: "✓"
            visible: root.injectionEnabled
            color: "white"
            font.pixelSize: 20
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.masterEnabled
            onClicked: {
                root.injectionEnabled = !root.injectionEnabled
                root.injectionToggled(root.pointKey, root.injectionEnabled)
            }
        }
    }

    Text {
        text: app.baseTopic + "/" + root.suffix
        anchors {
            left: parent.left
            leftMargin: 210
            right: unitText.left
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        color: colors.clockTileSelectedColor
        elide: Text.ElideMiddle
        font.pixelSize: qfont.metaText
    }

    Text {
        id: unitText
        text: root.unit
        width: 55
        horizontalAlignment: Text.AlignRight
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        color: "#333333"
        font.pixelSize: qfont.metaText
    }
}
