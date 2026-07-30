import QtQuick 2.1
import qb.components 1.0

Item {
    id: root
    width: parent ? parent.width : 890
    height: 27

    property string title: ""
    property string suffix: ""
    property string unit: ""

    Text {
        text: root.title
        width: 190
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        color: "#333333"
        font.pixelSize: qfont.metaText
    }

    Text {
        text: app.baseTopic + "/" + root.suffix
        anchors {
            left: parent.left
            leftMargin: 200
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
