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
            text: "No Phone Connected\nConnect via Bluetooth to view recent calls"
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
            id: recentsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: PhoneController.recentsModel
            clip: true
            spacing: 8

            delegate: Rectangle {
                // Force explicit width relative to the parent ListView to prevent circular implicit-width issues
                width: recentsList.width
                height: 64
                radius: 12
                color: typeof mainRoot !== "undefined" && !mainRoot.isNightMode ? Qt.rgba(0, 0, 0, 0.03) : Qt.rgba(1, 1, 1, 0.03)
                border.color: colorStroke

                // Left Call Type Icon
                Item {
                    id: typeIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    Image {
                        id: typeImg
                        anchors.fill: parent
                        source: {
                            if (model.type === "incoming")
                                return "qrc:/Assets/Phone/phone-call-inbound.svg";
                            if (model.type === "outgoing")
                                return "qrc:/Assets/Phone/phone-call-outbound.svg";
                            if (model.type === "missed")
                                return "qrc:/Assets/Phone/phone-call-missed.svg";
                            return "qrc:/Assets/Phone/phone.svg";
                        }
                        sourceSize.width: 64
                        sourceSize.height: 64
                        mipmap: true
                        fillMode: Image.PreserveAspectFit
                        visible: false
                    }
                    MultiEffect {
                        source: typeImg
                        anchors.fill: parent
                        colorization: 1.0
                        brightness: 1.0
                        colorizationColor: {
                            if (model.type === "incoming")
                                return "#4fc3f7"; // Light Blue for incoming
                            if (model.type === "outgoing")
                                return colorAccent; // Green for outgoing
                            if (model.type === "missed")
                                return "#ff5252"; // Red for missed
                            return colorTextMuted;
                        }
                    }
                }

                // Middle Text Labels Column (Centered and stretched)
                Column {
                    anchors.left: typeIcon.right
                    anchors.leftMargin: 16
                    anchors.right: callButton.left
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        width: parent.width
                        text: model.name !== "" ? model.name : model.number
                        color: colorTextPrimary
                        font.pixelSize: 16
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: model.time
                        color: colorTextMuted
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                }

                // Quick Call Button (Anchored strictly to the right side of the card)
                Rectangle {
                    id: callButton
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    radius: 18
                    color: Qt.rgba(0.71, 0.95, 0.42, 0.1)

                    Item {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        Image {
                            id: callImg
                            source: "qrc:/Assets/Phone/phone.svg"
                            anchors.fill: parent
                            sourceSize.width: 64
                            sourceSize.height: 64
                            mipmap: true
                            fillMode: Image.PreserveAspectFit
                            visible: false
                        }
                        MultiEffect {
                            source: callImg
                            anchors.fill: parent
                            colorization: 1.0
                            brightness: 1.0
                            colorizationColor: colorAccent
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: PhoneController.dial(model.number)
                    }
                }
            }
        }
    }
}
