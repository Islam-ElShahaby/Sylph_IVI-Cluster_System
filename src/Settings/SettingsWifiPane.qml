import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Sylph.Wifi 1.0

// Wi-Fi detail pane for the master-detail Settings screen.
Item {
    id: root

    property int radiusSmall: typeof mainRoot !== "undefined" ? mainRoot.radiusSmall : 16
    property color colorSurfaceAlt: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceAlt : "#dd141021"
    property color colorSurfaceInset: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceInset : Qt.rgba(0.17, 0.15, 0.22, 0.5)
    property color colorSurface: typeof mainRoot !== "undefined" ? mainRoot.colorSurface : "#c80e0a17"
    property color colorStroke: typeof mainRoot !== "undefined" ? mainRoot.colorStroke : "#2bffffff"
    property color colorTextPrimary: typeof mainRoot !== "undefined" ? mainRoot.colorTextPrimary : "#ffffff"
    property color colorTextMuted: typeof mainRoot !== "undefined" ? mainRoot.colorTextMuted : "#eae6f8"
    property color colorTextSubtle: typeof mainRoot !== "undefined" ? mainRoot.colorTextSubtle : "#b8b2c8"
    property color colorAccent: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"
    property color colorAccentAlt: typeof mainRoot !== "undefined" ? mainRoot.colorAccentAlt : "#7de2ff"

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        // -- Header: title + master toggle --
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "Wi-Fi"
                color: colorTextPrimary
                font.pixelSize: 20
                font.bold: true
                Layout.fillWidth: true
            }

            Text {
                text: !WifiController.available ? "Unavailable" : (WifiController.enabled ? "On" : "Off")
                color: colorTextSubtle
                font.pixelSize: 13
            }

            GlassSwitch {
                checked: WifiController.enabled
                enabled: WifiController.available
                checkedColor: colorAccent
                onToggled: isChecked => {
                    WifiController.setEnabled(isChecked);
                    if (isChecked)
                        WifiController.refresh();
                }
            }
        }

        // -- Status + actions --
        GlassPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            radiusSize: radiusSmall
            colorSurface: colorSurfaceInset

            RowLayout {
                anchors.fill: parent
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Status"
                        color: colorTextSubtle
                        font.pixelSize: 12
                    }
                    Text {
                        text: WifiController.connectedSsid !== "" ? "Connected to " + WifiController.connectedSsid : "Not connected"
                        color: colorTextPrimary
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                }

                Button {
                    text: WifiController.scanning ? "Scanning..." : "Rescan"
                    enabled: WifiController.available && WifiController.enabled && !WifiController.scanning
                    onClicked: WifiController.refresh()
                    background: Rectangle {
                        radius: 12
                        color: parent.down ? colorAccent : colorSurfaceAlt
                        border.color: colorStroke
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.down ? "#c80e0a17" : colorTextPrimary
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: "Disconnect"
                    enabled: WifiController.connectedSsid !== ""
                    onClicked: WifiController.disconnect()
                    background: Rectangle {
                        radius: 12
                        color: parent.down ? colorAccent : colorSurfaceAlt
                        border.color: colorStroke
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.down ? "#c80e0a17" : colorTextPrimary
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        Text {
            text: WifiController.lastError
            color: "#ff8e8e"
            font.pixelSize: 12
            visible: WifiController.lastError !== ""
            Layout.fillWidth: true
        }

        // -- Network list --
        Text {
            text: "Networks"
            color: colorTextSubtle
            font.pixelSize: 12
            font.bold: true
            Layout.topMargin: 2
        }

        ListView {
            id: wifiList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 10
            model: WifiController.networksModel
            currentIndex: -1

            Text {
                anchors.centerIn: parent
                text: WifiController.enabled ? "No networks found." : "Wi-Fi is disabled."
                color: colorTextSubtle
                font.pixelSize: 12
                visible: wifiList.count === 0
            }

            delegate: Rectangle {
                width: wifiList.width
                height: 56
                radius: radiusSmall
                color: ListView.isCurrentItem ? Qt.rgba(colorAccent.r, colorAccent.g, colorAccent.b, 0.15) : colorSurfaceInset
                border.color: ListView.isCurrentItem ? colorAccent : colorStroke
                border.width: 1

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                property string networkSsid: ssid
                property string networkSecurity: security
                property int networkSignal: signal
                property bool networkInUse: inUse

                // Signal + lock are anchored to the delegate's right edge so they
                // sit at the same x on every row regardless of network-name length.
                Text {
                    id: signalText
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42
                    horizontalAlignment: Text.AlignRight
                    text: networkSignal + "%"
                    color: colorTextSubtle
                    font.pixelSize: 12
                }

                Text {
                    id: lockText
                    anchors.right: signalText.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    horizontalAlignment: Text.AlignHCenter
                    text: (networkSecurity === "" || networkSecurity === "--") ? "" : "LCK"
                    font.pixelSize: 12
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: lockText.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: networkSsid !== "" ? networkSsid : "Hidden network"
                        color: colorTextPrimary
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: networkInUse
                            ? "Connected"
                            : ((networkSecurity === "" || networkSecurity === "--") ? "Open" : networkSecurity)
                        color: networkInUse ? colorAccentAlt : colorTextSubtle
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wifiList.currentIndex = index
                }
            }
        }

        // -- Connect / password --
        GlassPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            radiusSize: radiusSmall

            RowLayout {
                anchors.fill: parent
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: wifiList.currentItem ? ("Selected: " + wifiList.currentItem.networkSsid) : "Select a network"
                        color: colorTextPrimary
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    TextField {
                        id: wifiPassword
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        placeholderText: "Password (leave empty for open networks)"
                        enabled: wifiList.currentItem && !wifiList.currentItem.networkInUse
                        visible: wifiList.currentItem && wifiList.currentItem.networkSecurity !== "" && wifiList.currentItem.networkSecurity !== "--"
                        background: Rectangle {
                            radius: 10
                            color: colorSurfaceAlt
                            border.color: colorStroke
                        }
                        color: colorTextPrimary
                        placeholderTextColor: colorTextSubtle
                    }
                }

                Button {
                    text: "Connect"
                    enabled: wifiList.currentItem && !wifiList.currentItem.networkInUse && WifiController.enabled
                    onClicked: {
                        const ssid = wifiList.currentItem ? wifiList.currentItem.networkSsid : "";
                        WifiController.connectToNetwork(ssid, wifiPassword.text);
                    }
                    background: Rectangle {
                        radius: 12
                        color: parent.down ? colorAccent : colorSurfaceAlt
                        border.color: colorStroke
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.down ? "#c80e0a17" : colorTextPrimary
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
