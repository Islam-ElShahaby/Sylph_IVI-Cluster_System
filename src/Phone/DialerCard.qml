import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Sylph.Phone 1.0

Item {
    id: root

    property string currentNumber: ""
    
    // Theme properties from Main.qml
    property color colorTextPrimary: typeof mainRoot !== "undefined" ? mainRoot.colorTextPrimary : "#ffffff"
    property color colorTextMuted: typeof mainRoot !== "undefined" ? mainRoot.colorTextMuted : "#eae6f8"
    property color colorAccent: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"
    property color colorStroke: typeof mainRoot !== "undefined" ? mainRoot.colorStroke : "#2bffffff"
    property color colorSurfaceAlt: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceAlt : "#dd141021"

    RowLayout {
        anchors.centerIn: parent
        spacing: 64

        // Left Side: Keypad Grid
        GridLayout {
            Layout.alignment: Qt.AlignVCenter
            columns: 3
            rowSpacing: 16
            columnSpacing: 16

            Repeater {
                model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
                
                Rectangle {
                    width: 72
                    height: 72
                    radius: 36
                    color: mouseArea.pressed ? Qt.rgba(1,1,1,0.1) : colorSurfaceAlt
                    border.color: colorStroke

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: colorTextPrimary
                        font.pixelSize: 28
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        onClicked: root.currentNumber += modelData
                    }
                }
            }
        }

        // Right Side: Display and Actions
        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 32

            // Number Display
            Rectangle {
                Layout.preferredWidth: 320
                Layout.preferredHeight: 70
                color: Qt.rgba(0,0,0,0.2)
                radius: 16
                border.color: colorStroke

                Text {
                    anchors.centerIn: parent
                    text: root.currentNumber.length > 0 ? root.currentNumber : "Enter Number"
                    color: root.currentNumber.length > 0 ? colorTextPrimary : colorTextMuted
                    font.pixelSize: root.currentNumber.length > 0 ? 32 : 24
                    font.weight: Font.Light
                    font.letterSpacing: 2
                }
            }

            // Action Row
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 32

                // Call Button
                Rectangle {
                    width: 72
                    height: 72
                    radius: 36
                    color: callMouseArea.pressed ? Qt.darker(colorAccent, 1.2) : colorAccent

                    Item {
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        Image {
                            id: phoneImg
                            source: "qrc:/Assets/Phone/phone.svg"
                            anchors.fill: parent
                            sourceSize.width: 128
                            sourceSize.height: 128
                            mipmap: true
                            fillMode: Image.PreserveAspectFit
                            visible: false
                        }
                        MultiEffect {
                            source: phoneImg
                            anchors.fill: parent
                            colorization: 1.0
                            brightness: 1.0
                            colorizationColor: "#c80e0a17"
                        }
                    }

                    MouseArea {
                        id: callMouseArea
                        anchors.fill: parent
                        onClicked: {
                            if (root.currentNumber.length > 0) {
                                PhoneController.dial(root.currentNumber)
                            }
                        }
                    }
                }

                // Backspace Button
                Rectangle {
                    width: 72
                    height: 72
                    radius: 36
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "DEL"
                        color: colorTextMuted
                        font.pixelSize: 24
                        opacity: backspaceMouseArea.pressed ? 0.5 : 1.0
                    }

                    MouseArea {
                        id: backspaceMouseArea
                        anchors.fill: parent
                        onClicked: {
                            if (root.currentNumber.length > 0) {
                                root.currentNumber = root.currentNumber.substring(0, root.currentNumber.length - 1)
                            }
                        }
                        onPressAndHold: root.currentNumber = ""
                    }
                }
            }
        }
    }
}
