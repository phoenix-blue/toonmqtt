import QtQuick 2.1
import qb.components 1.0

Rectangle {
    id: root
    width: 220
    height: 40
    radius: 4

    property string text: ""
    property bool active: false
    signal clicked()

    color: root.active ? "#5b1f78" : (mouseArea.pressed ? "#969696" : "#b5b5b5")
    border.color: root.active ? "#421458" : "#a7a7a7"
    border.width: root.active ? 2 : 1

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 4
        color: "#8f49ad"
        visible: root.active
    }

    Text {
        anchors.centerIn: parent
        width: parent.width - 16
        text: root.text
        color: "white"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        font {
            family: root.active ? qfont.semiBold.name : qfont.regular.name
            pixelSize: qfont.bodyText
            bold: root.active
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
