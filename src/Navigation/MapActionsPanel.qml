import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: actionsPanelRoot

    property bool is3DMode: true
    property bool isNorthUp: false
    property bool isVoiceMuted: false

    property int radiusSmall: 16
    property color colorSurface: typeof mainRoot !== "undefined" ? mainRoot.colorSurface : Qt.rgba(0.12, 0.11, 0.16, 0.85)
    property color colorStroke: typeof mainRoot !== "undefined" ? mainRoot.colorStroke : Qt.rgba(1, 1, 1, 0.15)
    property color colorTextPrimary: typeof mainRoot !== "undefined" ? mainRoot.colorTextPrimary : "#ffffff"
    property color colorTextMuted: typeof mainRoot !== "undefined" ? mainRoot.colorTextMuted : "#b8b2c8"
    property color colorAccent: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"
    property color colorAccentAlt: typeof mainRoot !== "undefined" ? mainRoot.colorAccentAlt : "#7de2ff"

    signal zoomInRequested()
    signal zoomOutRequested()
    signal toggle3DRequested()
    signal toggleNorthUpRequested()
    signal toggleMuteRequested()

    width: 52
    height: 236
    radius: radiusSmall
    color: colorSurface
    border.color: colorStroke
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 8

        // Zoom In
        Button {
            Layout.fillWidth: true
            implicitHeight: 40
            flat: true
            background: null
            contentItem: Text {
                text: "+"
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: parent.down ? actionsPanelRoot.colorAccent : actionsPanelRoot.colorTextPrimary
            }
            onClicked: {
                actionsPanelRoot.zoomInRequested();
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: actionsPanelRoot.colorStroke
        }

        // Zoom Out
        Button {
            Layout.fillWidth: true
            implicitHeight: 40
            flat: true
            background: null
            contentItem: Text {
                text: "-"
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: parent.down ? actionsPanelRoot.colorAccent : actionsPanelRoot.colorTextPrimary
            }
            onClicked: {
                actionsPanelRoot.zoomOutRequested();
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: actionsPanelRoot.colorStroke
        }

        // Toggle 2D/3D Mode
        Button {
            id: toggle3DBtn
            Layout.fillWidth: true
            implicitHeight: 40
            flat: true
            background: null
            contentItem: Text {
                text: actionsPanelRoot.is3DMode ? "3D" : "2D"
                font.pixelSize: 13
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: actionsPanelRoot.is3DMode ? actionsPanelRoot.colorAccent : actionsPanelRoot.colorTextMuted
            }
            onClicked: {
                actionsPanelRoot.toggle3DRequested();
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: actionsPanelRoot.colorStroke
        }

        // Toggle North Up / Heading Up Mode
        Button {
            id: toggleNorthUpBtn
            Layout.fillWidth: true
            implicitHeight: 40
            flat: true
            background: null
            contentItem: Text {
                text: actionsPanelRoot.isNorthUp ? "NTH" : "HDG"
                font.pixelSize: 10
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: actionsPanelRoot.isNorthUp ? actionsPanelRoot.colorAccent : actionsPanelRoot.colorTextMuted
            }
            onClicked: {
                actionsPanelRoot.toggleNorthUpRequested();
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: actionsPanelRoot.colorStroke
        }

        // Mute Voice Guidance
        Button {
            Layout.fillWidth: true
            implicitHeight: 40
            flat: true
            background: null
            contentItem: Text {
                text: actionsPanelRoot.isVoiceMuted ? "OFF" : "ON"
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: actionsPanelRoot.isVoiceMuted ? "#ff5c77" : actionsPanelRoot.colorAccentAlt
            }
            onClicked: {
                actionsPanelRoot.toggleMuteRequested();
            }
        }
    }
}
