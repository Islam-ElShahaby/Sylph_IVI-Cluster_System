import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Sylph.Bluetooth 1.0

// Bluetooth detail pane for the master-detail Settings screen.
Item {
    id: root

    property int radiusSmall: typeof mainRoot !== "undefined" ? mainRoot.radiusSmall : 16
    property color colorSurfaceAlt: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceAlt : "#dd141021"
    property color colorSurfaceInset: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceInset : Qt.rgba(0.17, 0.15, 0.22, 0.5)
    property color colorStroke: typeof mainRoot !== "undefined" ? mainRoot.colorStroke : "#2bffffff"
    property color colorTextPrimary: typeof mainRoot !== "undefined" ? mainRoot.colorTextPrimary : "#ffffff"
    property color colorTextSubtle: typeof mainRoot !== "undefined" ? mainRoot.colorTextSubtle : "#b8b2c8"
    property color colorAccent: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"
    property color colorAccentAlt: typeof mainRoot !== "undefined" ? mainRoot.colorAccentAlt : "#7de2ff"

    Component.onCompleted: BtController.refreshPairedDevices()

    // Keep the bonded list current while this pane is shown.
    Timer {
        interval: 4000
        repeat: true
        running: BtController.enabled
        onTriggered: BtController.refreshPairedDevices()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        // -- Header: title + master toggle --
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "Bluetooth"
                color: colorTextPrimary
                font.pixelSize: 20
                font.bold: true
                Layout.fillWidth: true
            }

            Text {
                text: !BtController.enabled ? "Off" : (BtController.connected ? "Connected" : "On")
                color: colorTextSubtle
                font.pixelSize: 13
            }

            GlassSwitch {
                checked: BtController.enabled
                checkedColor: colorAccentAlt
                onToggled: isChecked => BtController.setEnabled(isChecked)
            }
        }

        // -- Device name (adapter alias) --
        GlassPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            radiusSize: radiusSmall
            colorSurface: colorSurfaceInset
            enabled: BtController.enabled
            opacity: BtController.enabled ? 1.0 : 0.5

            RowLayout {
                anchors.fill: parent
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: "Device name"
                        color: colorTextSubtle
                        font.pixelSize: 12
                    }

                    TextField {
                        id: nameField
                        Layout.fillWidth: true
                        
                        leftPadding: 10
                        rightPadding: 10

                        font.pixelSize: 15
                        font.bold: true
                        color: colorTextPrimary
                        placeholderText: "Sylph"
                        placeholderTextColor: colorTextSubtle
                        // Name shown to other devices when pairing
                        Component.onCompleted: text = BtController.deviceName
                        onEditingFinished: BtController.setDeviceName(text)
                        background: Rectangle {
                            radius: 10
                            color: "transparent"
                            border.color: nameField.activeFocus ? colorAccent : colorStroke
                            border.width: 1
                        }
                        Connections {
                            target: BtController
                            function onDeviceNameChanged() {
                                if (!nameField.activeFocus) nameField.text = BtController.deviceName
                            }
                        }
                    }
                }
            }
        }

        // -- Discoverable toggle --
        GlassPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            radiusSize: radiusSmall
            colorSurface: colorSurfaceInset
            enabled: BtController.enabled
            opacity: BtController.enabled ? 1.0 : 0.5

            RowLayout {
                anchors.fill: parent
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Discoverable"
                        color: colorTextPrimary
                        font.pixelSize: 14
                        font.bold: true
                    }
                    Text {
                        text: BtController.discoverable ? "Visible to nearby devices" : "Hidden from nearby devices"
                        color: colorTextSubtle
                        font.pixelSize: 12
                    }
                }

                GlassSwitch {
                    checked: BtController.discoverable
                    checkedColor: colorAccentAlt
                    onToggled: isChecked => BtController.setDiscoverable(isChecked)
                }
            }
        }

        // -- Paired devices --
        Text {
            text: "Paired devices"
            color: colorTextSubtle
            font.pixelSize: 12
            font.bold: true
            Layout.topMargin: 2
        }

        ListView {
            id: pairedList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 10
            model: BtController.pairedDevices

            Text {
                anchors.centerIn: parent
                width: parent.width - 24
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: !BtController.enabled ? "Bluetooth is off."
                    : "No paired devices yet.\nOn your phone, select \"" + BtController.deviceName + "\" to pair."
                color: colorTextSubtle
                font.pixelSize: 12
                visible: pairedList.count === 0
            }

            delegate: Rectangle {
                required property string name
                required property string address
                required property bool connected
                required property string path

                width: pairedList.width
                height: 64
                radius: radiusSmall
                color: colorSurfaceInset
                border.color: connected ? colorAccentAlt : colorStroke
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 200 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        text: "BT"
                        font.pixelSize: 20
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: name
                            color: colorTextPrimary
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: connected ? "Connected" : address
                            color: connected ? colorAccentAlt : colorTextSubtle
                            font.pixelSize: 11
                        }
                    }

                    // Connect / Disconnect
                    Rectangle {
                        Layout.preferredWidth: 104
                        Layout.preferredHeight: 36
                        radius: 10
                        color: cdMa.pressed ? Qt.rgba(colorAccent.r, colorAccent.g, colorAccent.b, 0.25) : "transparent"
                        border.color: colorStroke
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: connected ? "Disconnect" : "Connect"
                            color: colorTextPrimary
                            font.pixelSize: 12
                            font.bold: true
                        }
                        MouseArea {
                            id: cdMa
                            anchors.fill: parent
                            onClicked: connected ? BtController.disconnectDevice(path)
                                                 : BtController.connectDevice(path)
                        }
                    }

                    // Forget
                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 10
                        color: fgMa.pressed ? Qt.rgba(1, 0.4, 0.4, 0.22) : "transparent"
                        border.color: colorStroke
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "X"
                            color: "#ff8e8e"
                            font.pixelSize: 14
                            font.bold: true
                        }
                        MouseArea {
                            id: fgMa
                            anchors.fill: parent
                            onClicked: BtController.forgetDevice(path)
                        }
                    }
                }
            }
        }
    }
}
