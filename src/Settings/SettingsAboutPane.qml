import QtQuick
import QtQuick.Layouts

// About / system-info detail pane for the master-detail Settings screen.
Item {
    id: root

    property int radiusSmall: typeof mainRoot !== "undefined" ? mainRoot.radiusSmall : 16
    property color colorStroke: typeof mainRoot !== "undefined" ? mainRoot.colorStroke : "#2bffffff"
    property color colorTextPrimary: typeof mainRoot !== "undefined" ? mainRoot.colorTextPrimary : "#ffffff"
    property color colorTextSubtle: typeof mainRoot !== "undefined" ? mainRoot.colorTextSubtle : "#b8b2c8"
    property color colorAccent: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"

    // System info rows
    readonly property var infoRows: [
        { label: "Software version", value: "Sylph 0.1" },
        { label: "System",           value: "Qt " + qtVersion },
        { label: "Vehicle",          value: "Sylph Reference Head Unit" },
        { label: "Storage",          value: "Internal" }
    ]
    readonly property string qtVersion: "6.8"

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        Text {
            text: "About"
            color: colorTextPrimary
            font.pixelSize: 20
            font.bold: true
        }

        // -- Branding --
        GlassPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: 110
            radiusSize: radiusSmall

            RowLayout {
                anchors.fill: parent
                spacing: 16

                Rectangle {
                    width: 72
                    height: 72
                    radius: 20
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.colorAccent }
                        GradientStop { position: 1.0; color: Qt.darker(root.colorAccent, 1.6) }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "S"
                        color: "#ffffff"
                        font.pixelSize: 40
                        font.bold: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Sylph"
                        color: colorTextPrimary
                        font.pixelSize: 24
                        font.bold: true
                    }
                    Text {
                        text: "In-vehicle infotainment"
                        color: colorTextSubtle
                        font.pixelSize: 13
                    }
                }
            }
        }

        // -- Info list --
        GlassPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: infoColumn.implicitHeight + 32
            radiusSize: radiusSmall

            ColumnLayout {
                id: infoColumn
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: root.infoRows
                    delegate: ColumnLayout {
                        required property int index
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            Text {
                                text: modelData.label
                                color: colorTextSubtle
                                font.pixelSize: 13
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.value
                                color: colorTextPrimary
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: colorStroke
                            opacity: 0.5
                            visible: index < root.infoRows.length - 1
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            text: "© 2026 Sylph"
            color: colorTextSubtle
            font.pixelSize: 11
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
