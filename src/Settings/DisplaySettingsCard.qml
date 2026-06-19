import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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

    // Display settings state
    property real brightness: 0.8
    property bool autoBrightness: false
    property bool nightMode: typeof mainRoot !== "undefined" ? mainRoot.isNightMode : false
    property bool autoNightMode: typeof mainRoot !== "undefined" ? mainRoot.autoNightMode : true
    property bool sidebarIconOnly: typeof mainRoot !== "undefined" ? mainRoot.isSidebarIconOnly : false

    // Signals to broadcast theme changes to other components
    signal themeChanged(bool isNight)

    ScrollView {
        anchors.fill: parent
        contentWidth: -1   // disable horizontal scrolling
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: parent.width
            spacing: 14

        // -- SECTION HEADER --
        Text {
            text: "Display"
            color: colorTextPrimary
            font.pixelSize: 20
            font.bold: true
            Layout.bottomMargin: 2
        }

        // -- BRIGHTNESS CONTROL --
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            radius: radiusSmall
            color: colorSurfaceAlt
            border.color: colorStroke
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Screen Brightness"
                        color: colorTextPrimary
                        font.pixelSize: 14
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Text {
                        text: Math.round(root.brightness * 100) + "%"
                        color: colorAccent
                        font.pixelSize: 13
                        font.bold: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Slider {
                        id: brightnessSlider
                        Layout.fillWidth: true
                        from: 0.1
                        to: 1.0
                        value: root.brightness
                        enabled: !root.autoBrightness

                        onMoved: root.brightness = value

                        background: Rectangle {
                            x: brightnessSlider.leftPadding
                            y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                            implicitWidth: 200
                            implicitHeight: 6
                            width: brightnessSlider.availableWidth
                            height: implicitHeight
                            radius: 3
                            color: root.colorSurfaceInset

                            Rectangle {
                                width: brightnessSlider.visualPosition * parent.width
                                height: parent.height
                                radius: 3
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: root.nightMode ? "#4a4560" : "#b3a9d6" }
                                    GradientStop { position: 1.0; color: root.colorAccent }
                                }
                            }
                        }

                        handle: Rectangle {
                            x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                            y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: 10
                            color: brightnessSlider.pressed ? root.colorAccent : colorTextPrimary
                            border.color: root.colorStroke
                            border.width: 2

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }
            }
        }

        // -- AUTO BRIGHTNESS TOGGLE --
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            radius: radiusSmall
            color: colorSurfaceInset
            border.color: colorStroke
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                Text {
                    text: "Auto Brightness"
                    color: colorTextPrimary
                    font.pixelSize: 14
                    font.bold: true
                    Layout.fillWidth: true
                }

                GlassSwitch {
                    id: autoBrightnessToggle
                    checked: root.autoBrightness
                    checkedColor: colorAccentAlt
                    onToggled: (isChecked) => { root.autoBrightness = isChecked }
                }
            }
        }

        // -- DIVIDER --
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: colorStroke
            Layout.topMargin: 2
            Layout.bottomMargin: 2
        }

        // -- DAY / NIGHT MODE --
        Text {
            text: "Theme"
            color: colorTextPrimary
            font.pixelSize: 16
            font.bold: true
        }

        // Manual Day/Night Toggle
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 72
            radius: radiusSmall
            color: colorSurfaceAlt
            border.color: root.nightMode ? colorAccentAlt : colorAccent
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: 300 } }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                Text {
                    text: root.nightMode ? "Night Mode" : "Day Mode"
                    color: colorTextPrimary
                    font.pixelSize: 15
                    font.bold: true
                    Layout.fillWidth: true
                }

                GlassSwitch {
                    id: nightModeToggle
                    checked: root.nightMode
                    enabled: !root.autoNightMode
                    checkedColor: colorAccentAlt
                    onToggled: (isChecked) => {
                        if (typeof mainRoot !== "undefined") {
                            mainRoot.isNightMode = isChecked
                        } else {
                            root.nightMode = isChecked
                        }
                        root.themeChanged(isChecked)
                    }
                }
            }
        }

        // -- AUTO NIGHT MODE --
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            radius: radiusSmall
            color: colorSurfaceInset
            border.color: colorStroke
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                Text {
                    text: "Auto Day/Night"
                    color: colorTextPrimary
                    font.pixelSize: 14
                    font.bold: true
                    Layout.fillWidth: true
                }

                GlassSwitch {
                    id: autoNightToggle
                    checked: root.autoNightMode
                    checkedColor: colorAccent
                    onToggled: (isChecked) => {
                        if (typeof mainRoot !== "undefined")
                            mainRoot.autoNightMode = isChecked
                        else
                            root.autoNightMode = isChecked
                    }
                }
            }
        }

        // Auto day/night now runs in mainRoot (always alive); this pane just
        // toggles mainRoot.autoNightMode above.

        // -- DIVIDER --
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: root.colorStroke
            Layout.topMargin: 2
            Layout.bottomMargin: 2
        }

        // -- SIDEBAR STYLE --
        Text {
            text: "Sidebar Layout"
            color: root.colorTextPrimary
            font.pixelSize: 16
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 72
            radius: root.radiusSmall
            color: root.colorSurfaceAlt
            border.color: root.colorStroke
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14


                Text {
                    text: "Minimize Sidebar"
                    color: root.colorTextPrimary
                    font.pixelSize: 15
                    font.bold: true
                    Layout.fillWidth: true
                }

                GlassSwitch {
                    id: sidebarIconOnlyToggle
                    checked: root.sidebarIconOnly
                    checkedColor: root.colorAccent
                    onToggled: (isChecked) => {
                        if (typeof mainRoot !== "undefined") {
                            mainRoot.isSidebarIconOnly = isChecked
                        } else {
                            root.sidebarIconOnly = isChecked
                        }
                    }
                }
            }
        }

        Item { height: 8 }  // Bottom breathing room
        }
    }
}
