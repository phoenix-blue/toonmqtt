import QtQuick 2.1
import qb.components 1.0

Item {
    id: root
    width: 930
    height: 52

    property string pointKey: ""
    property string groupKey: ""
    property int rowIndex: 0
    property string labelText: ""
    property string displayName: ""
    property bool publishEnabled: true
    property bool writeEnabled: false
    property bool canWrite: false
    property bool availabilityKnown: false
    property bool pointAvailable: true
    property string sourceText: ""
    property string lastSeen: ""
    property string warningText: ""

    signal editNameRequested(string pointKey, string title, string value)

    Rectangle {
        anchors.fill: parent
        color: root.availabilityKnown && !root.pointAvailable ? "#eeeeee" :
               (root.rowIndex % 2 === 0 ? "#f4f4f4" : "#ffffff")
        border.color: "#dddddd"
    }

    Text {
        anchors {
            left: parent.left
            leftMargin: 12
            top: parent.top
            topMargin: 7
        }
        width: 300
        elide: Text.ElideRight
        text: root.labelText
        color: root.availabilityKnown && !root.pointAvailable ? "#777777" : "#222222"
        font.pixelSize: qfont.metaText
    }

    Text {
        anchors {
            left: parent.left
            leftMargin: 12
            bottom: parent.bottom
            bottomMargin: 6
        }
        width: 300
        elide: Text.ElideRight
        text: root.warningText.length > 0 ? "⚠ Mogelijk bronconflict" :
              (!root.availabilityKnown ? "Status wordt bepaald" :
               (root.pointAvailable ? "● Beschikbaar · " + root.sourceText :
                (root.lastSeen.length > 0 ? "○ Nu niet beschikbaar · " + root.sourceText :
                 "○ Niet aangetroffen · " + root.sourceText)))
        color: root.warningText.length > 0 ? "#a66a22" :
               (root.pointAvailable ? "#1c7a46" : "#777777")
        font.pixelSize: Math.max(12, qfont.metaText - 3)
    }

    Rectangle {
        id: publishBox
        width: 34
        height: 34
        anchors {
            left: parent.left
            leftMargin: 330
            verticalCenter: parent.verticalCenter
        }
        radius: 3
        color: root.publishEnabled ? "#6f2c91" : "#ffffff"
        border.color: root.publishEnabled ? "#6f2c91" : "#777777"
        border.width: 2

        Text {
            anchors.centerIn: parent
            text: "✓"
            visible: root.publishEnabled
            color: "white"
            font.pixelSize: 25
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.publishEnabled = !root.publishEnabled
        }
    }

    Rectangle {
        id: writeBox
        width: 34
        height: 34
        anchors {
            left: parent.left
            leftMargin: 440
            verticalCenter: parent.verticalCenter
        }
        radius: 3
        color: root.canWrite && root.writeEnabled ? "#6f2c91" : "#ffffff"
        border.color: root.canWrite ?
                      (root.writeEnabled ? "#6f2c91" : "#777777") : "#cccccc"
        border.width: 2
        opacity: root.canWrite ? 1 : 0.45

        Text {
            anchors.centerIn: parent
            text: root.canWrite ? "✓" : "–"
            visible: !root.canWrite || root.writeEnabled
            color: root.canWrite ? "white" : "#888888"
            font.pixelSize: 25
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.canWrite
            onClicked: root.writeEnabled = !root.writeEnabled
        }
    }

    Rectangle {
        anchors {
            left: parent.left
            leftMargin: 515
            right: parent.right
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        height: 38
        radius: 3
        color: "white"
        border.color: "#999999"

        Text {
            anchors {
                left: parent.left
                leftMargin: 10
                right: parent.right
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            elide: Text.ElideRight
            text: root.displayName
            color: "#222222"
            font.pixelSize: qfont.metaText
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.editNameRequested(root.pointKey,
                                              "MQTT-naam: " + root.labelText,
                                              root.displayName)
        }
    }
}
