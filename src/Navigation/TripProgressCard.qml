import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: tripRoot

    property string nextTurnStreet: ""
    property real distanceRemaining: 0.0
    property int timeRemaining: 0
    property real navigationProgress: 0.0
    property string etaTime: ""
    property bool isNightMode: true

    property int radiusSmall: 16
    property color colorSurface: isNightMode ? Qt.rgba(0.12, 0.11, 0.16, 0.85) : Qt.rgba(0.96, 0.95, 0.98, 0.40)
    property color colorStroke: "#2bffffff"
    property color colorTextPrimary: "#ffffff"
    property color colorTextSubtle: "#b8b2c8"
    property color colorTextMuted: "#eae6f8"
    property color colorAccent: "#c0b3ff"
    property color colorAccentAlt: "#7de2ff"

    width: parent ? parent.width - 36 : 400
    height: 72
    radius: radiusSmall
    color: colorSurface
    border.color: colorStroke
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 20

        // Next Step Quick Preview
        ColumnLayout {
            spacing: 2
            Text {
                text: "ARRIVING AT"
                color: tripRoot.colorTextSubtle
                font.pixelSize: 9
                font.bold: true
            }
            Text {
                text: tripRoot.nextTurnStreet
                color: tripRoot.colorTextPrimary
                font.pixelSize: 15
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.maximumWidth: 150
            }
        }

        // Route Progress Bar Indicator
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: tripRoot.distanceRemaining + " km left"
                    color: tripRoot.colorTextMuted
                    font.pixelSize: 11
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: tripRoot.timeRemaining + " mins left"
                    color: tripRoot.colorTextMuted
                    font.pixelSize: 11
                }
            }

            // Modern dynamic neon progress track
            Rectangle {
                id: progressTrack
                Layout.fillWidth: true
                height: 6
                radius: 3
                color: !tripRoot.isNightMode ? Qt.rgba(0, 0, 0, 0.08) : "#232031"
                border.color: tripRoot.colorStroke
                border.width: 0.5

                Rectangle {
                    height: parent.height
                    width: parent.width * tripRoot.navigationProgress
                    radius: 3
                    color: tripRoot.colorAccentAlt // Neon cyan bar
                }
            }
        }

        // Highlighted ETA Block
        Rectangle {
            width: 110
            height: 44
            radius: 10
            color: Qt.rgba(0.49, 0.89, 1.0, 0.12)
            border.color: Qt.rgba(0.49, 0.89, 1.0, 0.25)

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0
                Text {
                    text: "ETA"
                    color: tripRoot.colorAccentAlt
                    font.pixelSize: 9
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: tripRoot.etaTime
                    color: tripRoot.colorTextPrimary
                    font.pixelSize: 15
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}
