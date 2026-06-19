import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: directiveRoot

    property string nextTurnIcon: "^"
    property string nextTurnDistance: ""
    property string nextTurnStreet: ""
    property string currentStreet: ""
    property bool isPromptActive: false

    property int radiusSmall: 16
    property color colorSurface: typeof mainRoot !== "undefined" ? mainRoot.colorSurface : Qt.rgba(0.12, 0.11, 0.16, 0.85)
    property color colorStroke: "#2bffffff"
    property color colorTextMuted: "#eae6f8"
    property color colorTextPrimary: "#ffffff"
    property color colorTextSubtle: "#b8b2c8"
    property color colorAccent: "#c0b3ff"
    property color colorAccentAlt: "#7de2ff"

    signal voiceGuidanceRequested()

    width: 260
    height: isPromptActive ? 152 : 128
    radius: radiusSmall
    color: colorSurface
    border.color: colorStroke
    border.width: 1

    Behavior on height {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutQuad
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 4

        RowLayout {
            spacing: 12

            Rectangle {
                width: 42
                height: 42
                radius: 12
                color: Qt.rgba(0.71, 0.95, 0.42, 0.15)
                border.color: Qt.rgba(0.71, 0.95, 0.42, 0.3)

                Text {
                    anchors.centerIn: parent
                    text: directiveRoot.nextTurnIcon
                    font.pixelSize: 22
                    font.bold: true
                    color: directiveRoot.colorAccent
                }
            }

            ColumnLayout {
                spacing: 2
                Text {
                    text: "In " + directiveRoot.nextTurnDistance
                    color: directiveRoot.colorTextMuted
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    visible: directiveRoot.nextTurnDistance !== ""
                }
                Text {
                    text: directiveRoot.nextTurnStreet
                    color: directiveRoot.colorTextPrimary
                    font.pixelSize: 16
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.maximumWidth: 160
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: directiveRoot.colorStroke
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Current: <b>" + directiveRoot.currentStreet + "</b>"
                color: directiveRoot.colorTextSubtle
                font.pixelSize: 12
                textFormat: Text.RichText
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: directiveRoot.isPromptActive
            Text {
                text: "Guidance Voice Active"
                color: directiveRoot.colorAccentAlt
                font.pixelSize: 11
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: directiveRoot.isPromptActive
                    NumberAnimation {
                        from: 0.3
                        to: 1.0
                        duration: 600
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        from: 1.0
                        to: 0.3
                        duration: 600
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            directiveRoot.voiceGuidanceRequested();
        }
    }
}
