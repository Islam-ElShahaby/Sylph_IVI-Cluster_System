import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root

    property int currentIndex: 0
    property bool iconOnly: typeof mainRoot !== "undefined" ? mainRoot.isSidebarIconOnly : false
    property color colorTextPrimary: typeof mainRoot !== "undefined" ? mainRoot.colorTextPrimary : "#ffffff"
    property color colorTextMuted: typeof mainRoot !== "undefined" ? mainRoot.colorTextMuted : "#b8b2c8"
    property color colorAccent: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"
    property color colorSurface: typeof mainRoot !== "undefined" ? mainRoot.colorSurface : "#c80e0a17"

    // Layout metrics
    property real itemHeight: 52
    property real itemSpacing: 8 // Fixed spacing to group them together
    property real menuPadding: 24 // Padding around the menu block for the background
    property real totalMenuHeight: (menuModel.count * itemHeight) + (Math.max(0, menuModel.count - 1) * itemSpacing) + (menuPadding * 2)

    ListModel {
        id: menuModel
        ListElement {
            name: "Home"
            iconTxt: ""
            iconSource: "qrc:/Assets/tab_icons/Home.svg"
        }
        ListElement {
            name: "Navigation"
            iconTxt: ""
            iconSource: "qrc:/Assets/tab_icons/navigation.svg"
        }
        ListElement {
            name: "Media"
            iconTxt: ""
            iconSource: "qrc:/Assets/tab_icons/media.svg"
        }
        ListElement {
            name: "Phone"
            iconTxt: ""
            iconSource: "qrc:/Assets/Phone/phone.svg"
        }
        ListElement {
            name: "Weather"
            iconTxt: ""
            iconSource: "qrc:/Assets/tab_icons/weather.svg"
        }
        ListElement {
            name: "Climate"
            iconTxt: ""
            iconSource: "qrc:/Assets/tab_icons/AC.svg"
        }
        ListElement {
            name: "Settings"
            iconTxt: ""
            iconSource: "qrc:/Assets/tab_icons/settings.svg"
        }
    }

    // -- CENTERED MENU CONTAINER --
    Item {
        id: menuContainer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: root.totalMenuHeight

        property real activeY: root.menuPadding + root.currentIndex * (root.itemHeight + root.itemSpacing)

        // -- SLIDING BACKGROUNDS (Inverted Selection) --

        // Top Background Block
        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: root.iconOnly ? 8 : 12
            anchors.top: parent.top
            height: menuContainer.activeY
            clip: true

            Behavior on anchors.rightMargin {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: -20 // Keep left edge straight
                radius: 16
                color: root.colorSurface
            }

            Behavior on height {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Bottom Background Block
        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: root.iconOnly ? 8 : 12
            anchors.top: parent.top
            anchors.topMargin: menuContainer.activeY + root.itemHeight
            anchors.bottom: parent.bottom
            clip: true

            Behavior on anchors.rightMargin {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: -20 // Keep left edge straight
                radius: 16
                color: root.colorSurface
            }

            Behavior on anchors.topMargin {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Active Purple Highlight (Floating)
        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: 8  // highlight width is the reference -- background matches this in icon-only
            y: menuContainer.activeY
            height: root.itemHeight
            clip: true

            Behavior on anchors.rightMargin {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            Behavior on y {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }

            // Accent gradient background with right-rounded corners
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: -20
                radius: 20
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.45)
                    }
                    GradientStop {
                        position: 0.6
                        color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.08)
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }
            }

            // Left vertical accent line
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 4
                color: root.colorAccent
            }
        }

        // -- MENU ITEMS (Foreground) --
        Column {
            anchors.fill: parent
            anchors.topMargin: root.menuPadding
            anchors.bottomMargin: root.menuPadding
            spacing: root.itemSpacing

            Repeater {
                model: menuModel

                Item {
                    width: menuContainer.width
                    height: root.itemHeight
                    property bool isActive: index === root.currentIndex

                    // Hover highlight (only for non-active)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        color: Qt.rgba(1, 1, 1, 0.04)
                        visible: mouseArea.containsMouse && !isActive
                    }

                    // Icon + Label
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14

                        Item {
                            width: 20
                            height: 20
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: model.iconTxt
                                font.pixelSize: 18
                                color: isActive ? colorTextPrimary : colorTextMuted
                                opacity: isActive ? 1.0 : 0.55
                                visible: model.iconTxt !== ""

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 300
                                    }
                                }
                            }

                            Item {
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                visible: model.iconSource !== ""
                                Image {
                                    id: svgImg
                                    source: model.iconSource
                                    anchors.fill: parent
                                    sourceSize.width: 64
                                    sourceSize.height: 64
                                    mipmap: true
                                    fillMode: Image.PreserveAspectFit
                                    visible: false
                                }
                                MultiEffect {
                                    source: svgImg
                                    anchors.fill: parent
                                    colorization: 1.0
                                    brightness: 1.0
                                    colorizationColor: isActive ? colorTextPrimary : colorTextMuted
                                    opacity: isActive ? 1.0 : 0.55

                                    Behavior on colorizationColor {
                                        ColorAnimation {
                                            duration: 300
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            text: model.name
                            font.pixelSize: 16
                            font.weight: isActive ? Font.DemiBold : Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            color: isActive ? colorTextPrimary : colorTextMuted
                            // Fade based on the actual sidebar root width (72 -> 180)
                            opacity: Math.max(0.0, Math.min(1.0, (root.width - 72) / 108))
                            visible: opacity > 0.0

                            Behavior on color {
                                ColorAnimation {
                                    duration: 300
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentIndex = index
                    }
                }
            }
        }
    }
}
