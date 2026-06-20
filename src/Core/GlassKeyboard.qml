import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Rectangle {
    id: keyboardRoot

    property var targetField
    property int radiusSmall: 16
    property bool isNightMode: true
    property color colorSurface: isNightMode ? Qt.rgba(0.08, 0.07, 0.12, 0.94) : Qt.rgba(0.96, 0.95, 0.98, 0.94)
    property color colorStroke: "#2bffffff"
    property color colorTextPrimary: "#ffffff"
    property color colorTextMuted: "#eae6f8"
    property color colorAccent: "#c0b3ff"

    signal searchTriggered(string query)

    color: colorSurface
    border.color: colorStroke
    border.width: 1
    radius: radiusSmall

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        // Row 1: Q-P
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
                delegate: keyboardButtonDelegate
            }
        }

        // Row 2: A-L
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            spacing: 6
            Repeater {
                model: ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
                delegate: keyboardButtonDelegate
            }
        }

        // Row 3: Z-M + Backspace
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Item {
                width: 16
            }

            Repeater {
                model: ["Z", "X", "C", "V", "B", "N", "M"]
                delegate: keyboardButtonDelegate
            }

            Button {
                Layout.fillWidth: true
                implicitHeight: 52
                focusPolicy: Qt.NoFocus
                contentItem: Item {
                    Image {
                        id: delIcon
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: "qrc:/Assets/Keyboard/backspace.svg"
                        sourceSize.width: 48
                        sourceSize.height: 48
                        fillMode: Image.PreserveAspectFit
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: delIcon
                        source: delIcon
                        colorization: 1.0
                        colorizationColor: keyboardRoot.colorTextPrimary
                    }
                }
                background: Rectangle {
                    color: !keyboardRoot.isNightMode ? Qt.rgba(0.1, 0.08, 0.15, 0.1) : Qt.rgba(0.25, 0.20, 0.32, 0.6)
                    radius: 8
                    border.color: keyboardRoot.colorStroke
                }
                onClicked: {
                    if (keyboardRoot.targetField && keyboardRoot.targetField.text.length > 0) {
                        keyboardRoot.targetField.text = keyboardRoot.targetField.text.substring(0, keyboardRoot.targetField.text.length - 1);
                        keyboardRoot.targetField.textEdited(); // Notify listeners
                    }
                }
            }
        }

        // Row 4: Controls (Hide, Space, GO)
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Button {
                implicitWidth: 60
                implicitHeight: 52
                focusPolicy: Qt.NoFocus
                contentItem: Item {
                    Image {
                        id: hideIcon
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: "qrc:/Assets/Keyboard/keyboard-down.svg"
                        sourceSize.width: 48
                        sourceSize.height: 48
                        fillMode: Image.PreserveAspectFit
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: hideIcon
                        source: hideIcon
                        colorization: 1.0
                        colorizationColor: keyboardRoot.colorTextPrimary
                    }
                }
                background: Rectangle {
                    color: !keyboardRoot.isNightMode ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(0.2, 0.15, 0.25, 0.4)
                    radius: 8
                    border.color: keyboardRoot.colorStroke
                }
                onClicked: {
                    if (keyboardRoot.targetField) {
                        keyboardRoot.targetField.focus = false;
                    }
                }
            }

            Button {
                Layout.fillWidth: true
                implicitHeight: 52
                focusPolicy: Qt.NoFocus
                contentItem: Text {
                    text: "Space"
                    color: keyboardRoot.colorTextPrimary
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: !keyboardRoot.isNightMode ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(0.2, 0.15, 0.25, 0.4)
                    radius: 8
                    border.color: keyboardRoot.colorStroke
                }
                onClicked: {
                    if (keyboardRoot.targetField) {
                        keyboardRoot.targetField.text += " ";
                        keyboardRoot.targetField.textEdited();
                    }
                }
            }

            Button {
                implicitWidth: 80
                implicitHeight: 52
                focusPolicy: Qt.NoFocus
                contentItem: Text {
                    text: "GO"
                    color: !keyboardRoot.isNightMode ? "#ffffff" : keyboardRoot.colorTextPrimary
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: keyboardRoot.colorAccent
                    radius: 8
                }
                onClicked: {
                    if (keyboardRoot.targetField) {
                        keyboardRoot.searchTriggered(keyboardRoot.targetField.text);
                    }
                }
            }
        }
    }

    Component {
        id: keyboardButtonDelegate
        Button {
            Layout.fillWidth: true
            implicitHeight: 52
            focusPolicy: Qt.NoFocus
            contentItem: Text {
                text: modelData
                color: keyboardRoot.colorTextPrimary
                font.pixelSize: 18
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: !keyboardRoot.isNightMode ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(0.2, 0.15, 0.25, 0.4)
                radius: 8
                border.color: keyboardRoot.colorStroke
                border.width: 2
            }
            onClicked: {
                if (keyboardRoot.targetField) {
                    keyboardRoot.targetField.text += modelData.toLowerCase();
                    keyboardRoot.targetField.textEdited();
                }
            }
        }
    }
}
