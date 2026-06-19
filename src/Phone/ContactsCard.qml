import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Sylph.Phone 1.0

Item {
    id: root

    property color colorTextPrimary: typeof mainRoot !== "undefined" ? mainRoot.colorTextPrimary : "#ffffff"
    property color colorTextMuted: typeof mainRoot !== "undefined" ? mainRoot.colorTextMuted : "#eae6f8"
    property color colorStroke: typeof mainRoot !== "undefined" ? mainRoot.colorStroke : "#2bffffff"
    property color colorAccent: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"
    property color colorSurfaceAlt: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceAlt : "#dd141021"

    // Optional: Only show placeholder if not connected
    Item {
        anchors.fill: parent
        visible: !PhoneController.connected

        Text {
            anchors.centerIn: parent
            text: "No Phone Connected\nConnect via Bluetooth to view contacts"
            color: colorTextMuted
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.4
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16
        visible: PhoneController.connected

        ListView {
            id: contactsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: PhoneController.contactsModel
            clip: true
            spacing: 8

            delegate: Rectangle {
                id: delegateRect
                // Force explicit width relative to the parent ListView to prevent circular implicit-width issues
                width: contactsList.width
                height: Math.max(64, 40 + (model?.numbers ? model.numbers.length * 40 : 0))
                radius: 12
                color: typeof mainRoot !== "undefined" && !mainRoot.isNightMode ? Qt.rgba(0, 0, 0, 0.03) : Qt.rgba(1, 1, 1, 0.03)
                border.color: colorStroke

                // Left Avatar
                Rectangle {
                    id: avatarContainer
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    width: 40
                    height: 40
                    radius: 20
                    color: colorSurfaceAlt

                    Text {
                        anchors.centerIn: parent
                        text: model?.name ? model.name.charAt(0).toUpperCase() : "?"
                        color: colorTextMuted
                        font.pixelSize: 16
                    }
                }

                Text {
                    id: nameText
                    anchors.left: avatarContainer.right
                    anchors.leftMargin: 16
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    text: model?.name || ""
                    color: colorTextPrimary
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Column {
                    anchors.left: nameText.left
                    anchors.right: parent.right
                    anchors.top: nameText.bottom
                    anchors.topMargin: 4
                    spacing: 4

                    Repeater {
                        model: typeof numbers !== "undefined" ? numbers : []
                        delegate: Item {
                            width: parent.width
                            height: 36

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData
                                color: colorTextMuted
                                font.pixelSize: 14
                            }

                            // Quick Call Button
                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                width: 36
                                height: 36
                                radius: 18
                                color: Qt.rgba(0.71, 0.95, 0.42, 0.1) // Accent transparent

                                Item {
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    Image {
                                        id: phoneImg
                                        source: "qrc:/Assets/Phone/phone.svg"
                                        anchors.fill: parent
                                        sourceSize.width: 64
                                        sourceSize.height: 64
                                        mipmap: true
                                        fillMode: Image.PreserveAspectFit
                                        visible: false
                                    }
                                    MultiEffect {
                                        source: phoneImg
                                        anchors.fill: parent
                                        colorization: 1.0
                                        brightness: 1.0
                                        colorizationColor: colorAccent
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: PhoneController.dial(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
