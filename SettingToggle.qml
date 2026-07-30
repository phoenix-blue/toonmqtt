import QtQuick 2.1
import qb.components 1.0

Item {
    id: root
    width: 450
    height: 40

    property string label: ""
    property alias isSwitchedOn: toggle.isSwitchedOn

    Text {
        text: root.label
        width: parent.width - 110
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        color: "black"
        font.pixelSize: qfont.bodyText
    }

    OnOffToggle {
        id: toggle
        height: 36
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
    }
}
