import QtQuick
import QtQuick.Controls
import Sylph.Core 1.0

// -----------------------------------------------------------------------------
// DoorStatusPopup
//
// Floats top-right. Slides in when any door opens, slides out 2 s after all
// doors close. The car image is rotated 180 deg so the front (hood) faces UP.
// The image source binds straight to the door mask -- qrc PNGs are cached, so
// swaps are instant with no flicker. ponytail: was a dual-image crossfade with
// a reveal timer; the competing triggers caused the car to flash. Re-add a
// fade only if a genuinely animated transition is wanted.
// -----------------------------------------------------------------------------
Item {
    id: root

    // -- Palette forwarded from Main.qml --------------------------------------
    property color colorSurface:     Qt.rgba(0.06, 0.04, 0.10, 0.88)
    property color colorStroke:      Qt.rgba(1, 1, 1, 0.15)
    property color colorTextPrimary: "#ffffff"
    property color colorTextSubtle:  "#b8b2c8"
    property color colorAccent:      "#c0b3ff"

    // -- Image source lookup ---------------------------------------------------
    // Bit key: bit3=FL  bit2=FR  bit1=RL  bit0=RR
    readonly property var doorImageMap: ({
        0:  "qrc:/Assets/vehicle_door_states/doors_closed.png",
        8:  "qrc:/Assets/vehicle_door_states/doors_fl.png",
        4:  "qrc:/Assets/vehicle_door_states/doors_fr.png",
        2:  "qrc:/Assets/vehicle_door_states/doors_rl.png",
        1:  "qrc:/Assets/vehicle_door_states/doors_rr.png",
        12: "qrc:/Assets/vehicle_door_states/doors_fr_fl.png",
        10: "qrc:/Assets/vehicle_door_states/doors_fl_rl.png",
        9:  "qrc:/Assets/vehicle_door_states/doors_fl_rr.png",
        6:  "qrc:/Assets/vehicle_door_states/doors_fr_rl.png",
        5:  "qrc:/Assets/vehicle_door_states/doors_fr_rr.png",
        3:  "qrc:/Assets/vehicle_door_states/doors_rr_rl.png",
        14: "qrc:/Assets/vehicle_door_states/doors_fr_fl_rl.png",
        13: "qrc:/Assets/vehicle_door_states/doors_fr_fl_rr.png",
        11: "qrc:/Assets/vehicle_door_states/doors_fl_rr_rl.png",
        7:  "qrc:/Assets/vehicle_door_states/doors_fr_rr_rl.png",
        15: "qrc:/Assets/vehicle_door_states/doors_open.png"
    })

    function doorImageSource() {
        return doorImageMap[VehicleController.doorMask] || "qrc:/Assets/vehicle_door_states/doors_closed.png"
    }

    // -- Visibility state ------------------------------------------------------
    property bool popupVisible: false
    property int lastMask: 0

    // -- React to door changes -------------------------------------------------
    // Flash the full-screen takeover only when a door newly OPENS (a mask bit
    // goes 0->1), never on a close. Auto-releases after a few seconds. The
    // persistent "door open" warning lives in the status bar instead.
    // Show the popup and (re)arm the auto-release. Called on door-open and when
    // the status-bar warning is tapped.
    function flash() {
        popupVisible = true
        dismissTimer.restart()
    }

    Connections {
        target: VehicleController
        function onDoorMaskChanged(mask) {
            if ((mask & ~root.lastMask) !== 0)   // a door opened
                root.flash()
            root.lastMask = mask
        }
    }

    // Hold the full-screen takeover ~2.5 s, then release.
    Timer {
        id: dismissTimer
        interval: 2500
        repeat: false
        onTriggered: root.popupVisible = false
    }

    // -- Popup card ------------------------------------------------------------
    Rectangle {
        id: card
        width: root.width
        height: root.height
        radius: 22

        color: root.colorSurface
        border.color: root.colorStroke
        border.width: 1

        // Shimmer gradient
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.08) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.02) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.04) }
            }
        }

        // Accent top-edge highlight
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.width - (parent.radius * 2)
            height: 2
            radius: parent.radius
            color: VehicleController.anyDoorOpen ? "#ff9f43" : root.colorAccent

            SequentialAnimation on opacity {
                    running: VehicleController.anyDoorOpen
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                    onStopped: warningDot.opacity = 1.0
                }
        }

        // -- Full-screen fade + subtle scale ----------------------------------
        visible: opacity > 0
        opacity: root.popupVisible ? 1.0 : 0.0
        scale: root.popupVisible ? 1.0 : 1.05
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        // Swallow taps while the takeover is up
        MouseArea { anchors.fill: parent; enabled: root.popupVisible }

        // -- Header -----------------------------------------------------------
        Item {
            id: headerArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 16
            height: 32

            // Pulsing dot - color snaps instantly
            Rectangle {
                id: warningDot
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 8; height: 8; radius: 4
                color: VehicleController.anyDoorOpen ? "#ff9f43" : root.colorAccent

                SequentialAnimation on opacity {
                    running: VehicleController.anyDoorOpen
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                    onStopped: warningDot.opacity = 1.0
                }
            }

            Text {
                anchors.centerIn: parent
                text: VehicleController.anyDoorOpen ? "Door Open" : "Doors Closed"
                color: VehicleController.anyDoorOpen ? "#ff9f43" : root.colorAccent
                font.pixelSize: 14
                font.weight: Font.DemiBold
                font.letterSpacing: 0.4
            }
        }

        // Hairline divider
        Rectangle {
            id: divider
            anchors.top: headerArea.bottom
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            height: 1
            color: root.colorStroke
        }

        // -- Vehicle image stack -----------------------------------------------
        Item {
            id: imageContainer
            anchors.top: divider.bottom
            anchors.topMargin: 6
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12

            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                mipmap: false
                smooth: true
                rotation: 270
                scale: 1.5
                source: root.doorImageSource()
            }
        }
    }
}
