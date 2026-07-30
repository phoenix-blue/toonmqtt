import QtQuick 2.1
import qb.components 1.0

Tile {
    id: root

    property bool dimmed: screenStateController.dimmedColors

    onClicked: stage.openFullscreen(app.settingsUrl)

    Text {
        anchors {
            top: parent.top
            topMargin: 14
            horizontalCenter: parent.horizontalCenter
        }
        text: "Toon MQTT"
        color: dimmed ? "white" : "black"
        font {
            family: qfont.regular.name
            pixelSize: qfont.tileTitle
        }
    }

    Rectangle {
        width: 14
        height: 14
        radius: 7
        color: app.connected ? "#20a45b" : "#d64b3f"
        anchors {
            right: parent.right
            top: parent.top
            margins: 14
        }
    }

    Image {
        source: "drawables/MqttLogo.svg"
        width: parent.width * 0.48
        height: 48
        fillMode: Image.PreserveAspectFit
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: 45
        }
    }

    Text {
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: 28
        }
        text: app.connected ? "Verbonden" : "Niet verbonden"
        color: dimmableColors.tileTextColor
        font {
            family: qfont.semiBold.name
            pixelSize: qfont.tileText
        }
    }

    Text {
        anchors {
            bottom: parent.bottom
            bottomMargin: 14
            horizontalCenter: parent.horizontalCenter
        }
        width: parent.width - 20
        elide: Text.ElideMiddle
        horizontalAlignment: Text.AlignHCenter
        text: app.baseTopic
        color: dimmableColors.tileTextColor
        font {
            family: qfont.regular.name
            pixelSize: Math.round(qfont.tileText * 0.75)
        }
    }
}
