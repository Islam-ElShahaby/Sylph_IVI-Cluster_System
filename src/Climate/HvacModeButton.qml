import QtQuick
import QtQuick.Effects

Item {
    id: root
    width: 48
    height: 48

    property string iconSource: ""
    property bool isActive: false

    // Theme tokens
    property bool isNightMode: typeof mainRoot !== "undefined" ? mainRoot.isNightMode : true
    property color colorAccent: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: root.isActive
            ? (root.isNightMode ? "#33ffffff" : "#22000000")
            : (root.isNightMode ? "#11ffffff" : "#08000000")
        border.color: root.isActive
            ? (root.isNightMode ? "#66ffffff" : "#33000000")
            : (root.isNightMode ? "#22ffffff" : "#11000000")
        border.width: 1

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        Item {
            anchors.centerIn: parent
            width: 28
            height: 28

            Image {
                id: iconImg
                anchors.fill: parent
                source: root.iconSource
                sourceSize.width: 56
                sourceSize.height: 56
                mipmap: true
                fillMode: Image.PreserveAspectFit
                visible: false
            }

            MultiEffect {
                source: iconImg
                anchors.fill: parent
                colorization: 1.0
                brightness: 1.0
                colorizationColor: root.isActive ? "#ffffff" : "#88ffffff"
                opacity: root.isActive ? 1.0 : 0.5

                Behavior on opacity { NumberAnimation { duration: 200 } }
                Behavior on colorizationColor { ColorAnimation { duration: 200 } }
            }
        }

        scale: mouseArea.pressed ? 0.9 : 1.0
        Behavior on scale { NumberAnimation { duration: 100 } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        onClicked: {
            root.isActive = !root.isActive
        }
    }
}
