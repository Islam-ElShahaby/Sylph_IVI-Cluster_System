import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Window

// Master-detail Settings screen: a category sidebar on the left and a swapping
// detail pane on the right -- like a phone / car settings app.
Item {
    id: root

    property int radiusLarge: typeof mainRoot !== "undefined" ? mainRoot.radiusLarge : 28
    property int radiusSmall: typeof mainRoot !== "undefined" ? mainRoot.radiusSmall : 16
    property color colorSurface: typeof mainRoot !== "undefined" ? mainRoot.colorSurface : "#c80e0a17"
    property color colorSurfaceAlt: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceAlt : "#dd141021"
    property color colorStroke: typeof mainRoot !== "undefined" ? mainRoot.colorStroke : "#2bffffff"
    property color colorTextPrimary: typeof mainRoot !== "undefined" ? mainRoot.colorTextPrimary : "#ffffff"
    property color colorTextSubtle: typeof mainRoot !== "undefined" ? mainRoot.colorTextSubtle : "#b8b2c8"
    property color colorAccent: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"
    property color colorAccentAlt: typeof mainRoot !== "undefined" ? mainRoot.colorAccentAlt : "#7de2ff"
    property bool isNightMode: typeof mainRoot !== "undefined" ? mainRoot.isNightMode : true

    property int selectedIndex: 0

    // The currently focused text field anywhere in the detail pane, or null.
    // echoMode only exists on TextInput/TextField, so it filters out non-editors.
    readonly property Item kbTarget: {
        var it = root.Window.activeFocusItem
        return (it && it.echoMode !== undefined) ? it : null
    }

    readonly property var categories: [
        { name: "Wi-Fi" },
        { name: "Bluetooth" },
        { name: "Display" },
        { name: "Date & Time" },
        { name: "Audio" },
        { name: "Weather" },
        { name: "About" }
    ]

    // -- Glassmorphism card background (matches the other screens) --
    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: radiusLarge
        color: colorSurface
        border.color: colorStroke
        border.width: 1
        visible: false
    }

    MultiEffect {
        source: cardBg
        anchors.fill: cardBg
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 32
        blurMultiplier: 1.0
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.4
        shadowBlur: 20
        shadowVerticalOffset: 10
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        // ============================================
        //  SIDEBAR -- category list
        // ============================================
        ColumnLayout {
            // A ColumnLayout defaults Layout.fillWidth to true -- pin it off so
            // the sidebar keeps its fixed width and the detail pane gets the rest.
            Layout.fillWidth: false
            Layout.preferredWidth: 210
            Layout.fillHeight: true
            spacing: 6

            Text {
                text: "Settings"
                color: colorTextPrimary
                font.pixelSize: 22
                font.bold: true
                Layout.leftMargin: 6
                Layout.bottomMargin: 10
            }

            Repeater {
                model: root.categories

                delegate: Rectangle {
                    id: catRow
                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: radiusSmall

                    readonly property bool active: index === root.selectedIndex

                    color: active
                        ? Qt.rgba(colorAccent.r, colorAccent.g, colorAccent.b, 0.18)
                        : (catMa.pressed ? Qt.rgba(colorAccent.r, colorAccent.g, colorAccent.b, 0.08) : "transparent")
                    border.color: active
                        ? Qt.rgba(colorAccent.r, colorAccent.g, colorAccent.b, 0.45)
                        : "transparent"
                    border.width: 1

                    Behavior on color        { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 12

                        Text {
                            text: catRow.modelData.name
                            color: catRow.active ? colorTextPrimary : colorTextSubtle
                            font.pixelSize: 15
                            font.bold: catRow.active
                            Layout.fillWidth: true
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Text {
                            text: "›"
                            color: colorTextSubtle
                            font.pixelSize: 18
                            opacity: catRow.active ? 1.0 : 0.4
                        }
                    }

                    MouseArea {
                        id: catMa
                        anchors.fill: parent
                        onClicked: root.selectedIndex = catRow.index
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        // -- Vertical separator --
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: colorStroke
            opacity: 0.6
        }

        // ============================================
        //  DETAIL -- swapping pane
        // ============================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Loader {
                id: detailLoader
                anchors.fill: parent
                opacity: 0
                sourceComponent: [wifiPane, btPane, displayPane, timePane, audioPane, weatherPane, aboutPane][root.selectedIndex]
                onLoaded: detailFade.restart()
            }

            NumberAnimation {
                id: detailFade
                target: detailLoader
                property: "opacity"
                from: 0; to: 1
                duration: 220
                easing.type: Easing.OutQuad
            }
        }
    }

    // -- Shared virtual keyboard: spans the whole card, drives the focused field --
    MouseArea {
        anchors.fill: parent
        enabled: settingsKeyboard.height > 0
        visible: settingsKeyboard.height > 0
        z: 9
        onClicked: if (root.kbTarget) root.kbTarget.focus = false
    }

    Rectangle {
        anchors.fill: settingsKeyboard
        anchors.margins: -4
        radius: settingsKeyboard.radius + 2
        color: "#000000"
        opacity: root.isNightMode ? 0.35 : 0.08
        z: settingsKeyboard.z - 1
        visible: settingsKeyboard.height > 0
    }

    GlassKeyboard {
        id: settingsKeyboard
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 20
        height: root.kbTarget ? 260 : 0
        z: 10
        clip: true
        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        isNightMode: root.isNightMode
        targetField: root.kbTarget
        radiusSmall: root.radiusSmall
        colorSurface: root.colorSurfaceAlt
        colorStroke: root.colorStroke
        colorTextPrimary: root.colorTextPrimary
        colorTextMuted: root.colorTextSubtle
        colorAccent: root.colorAccent
        onSearchTriggered: if (root.kbTarget) root.kbTarget.focus = false
    }

    // -- Detail pane components --
    Component { id: wifiPane;    SettingsWifiPane {} }
    Component { id: btPane;      SettingsBluetoothPane {} }
    Component { id: displayPane; DisplaySettingsCard {} }
    Component { id: timePane;    TimeSettingsPane {} }
    Component { id: audioPane;   AudioSettingsCard {} }
    Component { id: weatherPane; SettingsWeatherPane {} }
    Component { id: aboutPane;   SettingsAboutPane {} }
}
