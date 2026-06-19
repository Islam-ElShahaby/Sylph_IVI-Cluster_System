import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: climateCard

    // Theme tokens from mainRoot
    property bool isNightMode: typeof mainRoot !== "undefined" ? mainRoot.isNightMode : true
    property int radiusLarge: typeof mainRoot !== "undefined" ? mainRoot.radiusLarge : 28
    property int radiusSmall: typeof mainRoot !== "undefined" ? mainRoot.radiusSmall : 16
    property color colorSurface: typeof mainRoot !== "undefined" ? mainRoot.colorSurface : Qt.rgba(0.06, 0.04, 0.10, 0.65)
    property color colorSurfaceAlt: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceAlt : Qt.rgba(0.09, 0.07, 0.15, 0.75)
    property color colorStroke: typeof mainRoot !== "undefined" ? mainRoot.colorStroke : Qt.rgba(1, 1, 1, 0.15)
    property color colorTextPrimary: typeof mainRoot !== "undefined" ? mainRoot.colorTextPrimary : "#ffffff"
    property color colorTextMuted: typeof mainRoot !== "undefined" ? mainRoot.colorTextMuted : "#eae6f8"
    property color colorTextSubtle: typeof mainRoot !== "undefined" ? mainRoot.colorTextSubtle : "#b8b2c8"
    property color colorAccent: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"
    property color colorAccentAlt: typeof mainRoot !== "undefined" ? mainRoot.colorAccentAlt : "#7de2ff"

    // Climate state. The fan is the master power switch (see
    // fanArc.onCurrentSpeedChanged): fan at 0 powers the system off -- mode
    // buttons + flow selector lock and circulation reverts to fresh air. The
    // A/C button only toggles the compressor (acOn); it never touches the fan.
    property bool acOn: true                  // compressor / cooling on
    property bool autoMode: false
    property bool dualZone: true              // true = independent zones; false = passenger follows driver
    property bool circulationExternal: false  // false = internal recirculation, true = fresh air
    property int  flowMode: 0                 // 0 = face, 1 = face+feet, 2 = feet

    // System power follows the fan; drives the control lock when off.
    readonly property bool systemOn: fanArc.currentSpeed > 0
    property int _prevFanSpeed: 3

    // Expose key values for home quick controls.
    property alias driverTemperature: driverDial.temperature
    property alias passengerTemperature: passengerDial.temperature
    property alias fanSpeed: fanArc.currentSpeed
    property alias maxFanSpeed: fanArc.maxSpeed
    property alias minTemp: driverDial.minTemp
    property alias maxTemp: driverDial.maxTemp

    // Auto & Dual-Zone depend on the compressor: they switch off and lock
    // whenever A/C is turned off (via the A/C button or by killing the fan).
    // Dual-Zone off = the two dials are coupled (passenger follows driver).
    onAcOnChanged: {
        if (!acOn) {
            autoMode = false
            dualZone = false
        }
    }

    // -- Glassmorphism card background --
    // Plain translucent rect. Blurring a flat rounded rect through MultiEffect
    // (blurMax 32 + shadow) was visually a no-op but compiled a huge blur
    // shader chain on first show -- the main cause of the multi-second hang on
    // the Pi when the card first became visible.
    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: climateCard.radiusLarge
        color: climateCard.colorSurface
        border.color: climateCard.colorStroke
        border.width: 1
    }

    // -- Main Content --
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        // -- Main Control Area --
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(260, climateCard.height * 0.5)
            spacing: 12

            // --- Driver Side ---
            ColumnLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: climateCard.width * 0.3
                spacing: 8

                Item { Layout.fillHeight: true }

                AcDial {
                    id: driverDial
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(190, parent.width - 12)
                    Layout.preferredHeight: Layout.preferredWidth
                    dialColor: climateCard.colorAccent
                    temperature: 22
                    acOn: climateCard.acOn
                    disabled: climateCard.autoMode
                    // Whole dial dims when A/C is off
                    opacity: climateCard.acOn ? 1.0 : 0.45
                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.InOutQuad } }
                    onTemperatureChanged: {
                        if (!climateCard.dualZone) passengerDial.temperature = temperature
                    }
                }

                Text {
                    text: "Driver"
                    color: climateCard.colorTextSubtle
                    font.pixelSize: 13
                    Layout.alignment: Qt.AlignHCenter
                }

                Item { Layout.fillHeight: true }
            }

            // --- Center: Fan Arc + Mode Chips ---
            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                spacing: 8

                Item { Layout.fillHeight: true }

                // A/C | Auto | Dual-Zone -- above the fan arc.
                // Locked + dimmed while the system is off (raise the fan to restore).
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    enabled: climateCard.systemOn
                    opacity: climateCard.systemOn ? 1.0 : 0.4
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

                    // Shared chip colours derived from the app accent
                    // active bg  : accent @ 22 %   active border: accent @ 55 %
                    // inactive bg: surface tint     inactive border: stroke tint

                    // A/C toggle
                    Rectangle {
                        width: 56; height: 36; radius: 10
                        color: climateCard.acOn
                            ? Qt.rgba(climateCard.colorAccent.r, climateCard.colorAccent.g, climateCard.colorAccent.b, 0.22)
                            : climateCard.colorSurface
                        border.color: climateCard.acOn
                            ? Qt.rgba(climateCard.colorAccent.r, climateCard.colorAccent.g, climateCard.colorAccent.b, 0.55)
                            : climateCard.colorStroke
                        border.width: 1
                        Behavior on color        { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                        Text {
                            anchors.centerIn: parent
                            text: "A/C"
                            color: climateCard.acOn ? climateCard.colorTextPrimary : climateCard.colorTextSubtle
                            font.pixelSize: 12; font.bold: true
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        scale: acMa.pressed ? 0.9 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        // A/C button toggles the compressor only -- never the fan
                        MouseArea { id: acMa; anchors.fill: parent; onClicked: climateCard.acOn = !climateCard.acOn }
                    }

                    // Auto -- sets both temperatures to 20  degC.
                    // Disabled while A/C is off.
                    Rectangle {
                        width: 56; height: 36; radius: 10
                        enabled: climateCard.acOn
                        opacity: climateCard.acOn ? 1.0 : 0.4
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        color: climateCard.autoMode
                            ? Qt.rgba(climateCard.colorAccent.r, climateCard.colorAccent.g, climateCard.colorAccent.b, 0.22)
                            : climateCard.colorSurface
                        border.color: climateCard.autoMode
                            ? Qt.rgba(climateCard.colorAccent.r, climateCard.colorAccent.g, climateCard.colorAccent.b, 0.55)
                            : climateCard.colorStroke
                        border.width: 1
                        Behavior on color        { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                        Text {
                            anchors.centerIn: parent
                            text: "AUTO"
                            color: climateCard.autoMode ? climateCard.colorTextPrimary : climateCard.colorTextSubtle
                            font.pixelSize: 11; font.bold: true
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        scale: autoMa.pressed ? 0.9 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        MouseArea {
                            id: autoMa; anchors.fill: parent
                            onClicked: {
                                climateCard.autoMode = !climateCard.autoMode
                                if (climateCard.autoMode) {
                                    driverDial.temperature = 20
                                    passengerDial.temperature = 20
                                }
                            }
                        }
                    }

                    // Dual-Zone -- when ON the two dials are independent; when OFF
                    // the passenger follows the driver. Disabled while A/C is off,
                    // or while Auto is on (Auto already drives both dials).
                    Rectangle {
                        width: dualZoneText.implicitWidth + 22; height: 36; radius: 10
                        enabled: climateCard.acOn && !climateCard.autoMode
                        opacity: (climateCard.acOn && !climateCard.autoMode) ? 1.0 : 0.4
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        color: climateCard.dualZone
                            ? Qt.rgba(climateCard.colorAccent.r, climateCard.colorAccent.g, climateCard.colorAccent.b, 0.22)
                            : climateCard.colorSurface
                        border.color: climateCard.dualZone
                            ? Qt.rgba(climateCard.colorAccent.r, climateCard.colorAccent.g, climateCard.colorAccent.b, 0.55)
                            : climateCard.colorStroke
                        border.width: 1
                        Behavior on color        { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                        Text {
                            id: dualZoneText
                            anchors.centerIn: parent
                            text: "Dual-Zone"
                            color: climateCard.dualZone ? climateCard.colorTextPrimary : climateCard.colorTextSubtle
                            font.pixelSize: 11; font.bold: true
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        scale: dualMa.pressed ? 0.9 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        MouseArea {
                            id: dualMa; anchors.fill: parent
                            onClicked: {
                                climateCard.dualZone = !climateCard.dualZone
                                // Leaving dual-zone re-couples: snap passenger to driver.
                                if (!climateCard.dualZone)
                                    passengerDial.temperature = driverDial.temperature
                            }
                        }
                    }
                }

                FanSpeedArc {
                    id: fanArc
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 380
                    Layout.preferredHeight: 210
                    arcCenterYOffset: 390
                    currentSpeed: 3
                    // Fan is the master power switch. Crossing 0 powers the
                    // system off/on and the compressor follows that transition;
                    // adjusting between non-zero speeds leaves the compressor alone.
                    onCurrentSpeedChanged: {
                        if (currentSpeed === 0) {
                            climateCard.acOn = false                 // clears auto/sync via onAcOnChanged
                            climateCard.circulationExternal = true   // fresh air when off
                        } else if (climateCard._prevFanSpeed === 0) {
                            climateCard.acOn = true                  // powering back on
                        }
                        climateCard._prevFanSpeed = currentSpeed
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // --- Passenger Side ---
            ColumnLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: climateCard.width * 0.3
                spacing: 8

                Item { Layout.fillHeight: true }

                AcDial {
                    id: passengerDial
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(190, parent.width - 12)
                    Layout.preferredHeight: Layout.preferredWidth
                    dialColor: climateCard.colorAccent
                    temperature: 20
                    flipArc: true
                    acOn: climateCard.acOn
                    disabled: climateCard.autoMode
                    // Whole dial dims only when A/C is off; coupling (dual-zone off)
                    // dims just the slider so the mirrored temperature stays readable.
                    opacity: climateCard.acOn ? 1.0 : 0.45
                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.InOutQuad } }
                    sliderOpacity: climateCard.dualZone ? 1.0 : 0.35
                }

                Text {
                    text: "Passenger"
                    color: climateCard.colorTextSubtle
                    font.pixelSize: 13
                    Layout.alignment: Qt.AlignHCenter
                }

                Item { Layout.fillHeight: true }
            }
        }

        // -- Flowing Curved Panel --
        Item {
            id: flowingPanel
            Layout.fillWidth: true
            Layout.preferredHeight: 165

        Shape {
            id: flowingSeparator
            anchors.fill: parent
            opacity: 0.55
            ShapePath {
                strokeColor: climateCard.colorStroke
                strokeWidth: 1.5
                fillColor: climateCard.colorSurfaceAlt
                capStyle: ShapePath.RoundCap
                startX: climateCard.radiusSmall; startY: 1
                PathLine { x: flowingSeparator.width * 0.18; y: 1 }
                PathCubic {
                    control1X: flowingSeparator.width * 0.30; control1Y: 1
                    control2X: flowingSeparator.width * 0.37; control2Y: 56
                    x: flowingSeparator.width * 0.50; y: 56
                }
                PathCubic {
                    control1X: flowingSeparator.width * 0.63; control1Y: 56
                    control2X: flowingSeparator.width * 0.70; control2Y: 1
                    x: flowingSeparator.width * 0.82; y: 1
                }
                PathLine { x: flowingSeparator.width - climateCard.radiusSmall; y: 1 }
                PathArc {
                    x: flowingSeparator.width; y: 1 + climateCard.radiusSmall
                    radiusX: climateCard.radiusSmall; radiusY: climateCard.radiusSmall
                    direction: PathArc.Clockwise
                }
                // Close down the sides + across the bottom so the curve reads
                // as a solid object, with all four corners rounded.
                PathLine { x: flowingSeparator.width; y: flowingSeparator.height - climateCard.radiusSmall }
                PathArc {
                    x: flowingSeparator.width - climateCard.radiusSmall; y: flowingSeparator.height
                    radiusX: climateCard.radiusSmall; radiusY: climateCard.radiusSmall
                    direction: PathArc.Clockwise
                }
                PathLine { x: climateCard.radiusSmall; y: flowingSeparator.height }
                PathArc {
                    x: 0; y: flowingSeparator.height - climateCard.radiusSmall
                    radiusX: climateCard.radiusSmall; radiusY: climateCard.radiusSmall
                    direction: PathArc.Clockwise
                }
                PathLine { x: 0; y: 1 + climateCard.radiusSmall }
                PathArc {
                    x: climateCard.radiusSmall; y: 1
                    radiusX: climateCard.radiusSmall; radiusY: climateCard.radiusSmall
                    direction: PathArc.Clockwise
                }
            }
        }

        // -- Flow mode selector -- floats in the bay ABOVE the dip curve --
        // Clean capsule pill; the negative top margin lifts it clear of the
        // panel's dip line so the curve reads as its own stroke underneath.
        ColumnLayout {
            id: flowSelector
            anchors.top: parent.top
            anchors.topMargin: -20
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            Item {
                id: flowCurve
                Layout.alignment: Qt.AlignHCenter
                width: 184
                height: 54

                readonly property real h: 40          // pill thickness
                readonly property real bow: 14        // centre dip depth
                readonly property real cy: h / 2      // centreline height at the edges
                readonly property real x0: h / 2      // cap-radius inset
                readonly property real x1: width - h / 2
                // animated position along the centreline -- Animating t -- not x/y directly 
                property real posT: slotT(climateCard.flowMode)
                Behavior on posT { NumberAnimation { duration: 280; easing.type: Easing.InOutQuad } }
                // continuous samplers along the centreline quad
                function slotT(i) { return (i * 2 + 1) / 6 }
                function xAt(t) { return x0 + t * (x1 - x0) }
                function yAt(t) { return cy + 4 * bow * (1 - t) * t }
                function angleAt(t) { return Math.atan2(4 * bow * (1 - 2 * t), x1 - x0) * 180 / Math.PI }

                Shape {
                    anchors.fill: parent
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: climateCard.colorSurface
                        strokeWidth: flowCurve.h
                        capStyle: ShapePath.RoundCap
                        startX: flowCurve.x0; startY: flowCurve.cy
                        PathQuad {
                            x: flowCurve.x1; y: flowCurve.cy
                            controlX: flowCurve.width / 2; controlY: flowCurve.cy + flowCurve.bow * 2
                        }
                    }
                }

                // Pill-shaped highlight -- rides the curve to the active slot.
                Rectangle {
                    id: flowIndicator
                    width: 50; height: flowCurve.h - 6; radius: height / 2
                    // Derived from posT, so it sweeps along the curve as posT animates.
                    x: flowCurve.xAt(flowCurve.posT) - width / 2
                    y: flowCurve.yAt(flowCurve.posT) - height / 2
                    rotation: flowCurve.angleAt(flowCurve.posT)   // bank with the curve
                    transformOrigin: Item.Center
                    color: Qt.rgba(climateCard.colorAccent.r, climateCard.colorAccent.g, climateCard.colorAccent.b, 0.25)
                    border.color: Qt.rgba(climateCard.colorAccent.r, climateCard.colorAccent.g, climateCard.colorAccent.b, 0.50)
                    border.width: 1
                    opacity: climateCard.systemOn ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                }

                // Icons, each centred on its slot point along the curve.
                Repeater {
                    model: [
                        { src: "qrc:/Assets/Climate/parallel.svg",      mode: 0 },
                        { src: "qrc:/Assets/Climate/parallel-feet.svg", mode: 1 },
                        { src: "qrc:/Assets/Climate/feet.svg",          mode: 2 }
                    ]
                    delegate: Item {
                        width: 24; height: 24
                        x: flowCurve.xAt(flowCurve.slotT(modelData.mode)) - 12
                        y: flowCurve.yAt(flowCurve.slotT(modelData.mode)) - 12
                        Image {
                            id: flowIcon; anchors.fill: parent
                            source: modelData.src
                            sourceSize: Qt.size(48, 48); mipmap: true
                            fillMode: Image.PreserveAspectFit; visible: false
                        }
                        MultiEffect {
                            source: flowIcon; anchors.fill: flowIcon
                            colorization: 1.0; brightness: 1.0
                            colorizationColor: (climateCard.systemOn && climateCard.flowMode === modelData.mode) ? climateCard.colorTextPrimary : climateCard.colorAccent
                            opacity: (climateCard.systemOn && climateCard.flowMode === modelData.mode) ? 1.0 : 0.45
                            Behavior on opacity           { NumberAnimation { duration: 200 } }
                            Behavior on colorizationColor { ColorAnimation  { duration: 200 } }
                        }
                    }
                }

                // Tap zones -- one per third, full height. Locked while off.
                Row {
                    anchors.fill: parent
                    enabled: climateCard.systemOn
                    Repeater {
                        model: 3
                        delegate: MouseArea {
                            width: flowCurve.width / 3; height: flowCurve.height
                            onClicked: climateCard.flowMode = index
                        }
                    }
                }
            }
        }

        // -- Seat controls & circulation, inside the curved object --
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 95
            spacing: 0

            Item { Layout.preferredWidth: 12 }

            HvacflowButton {
                label: "Driver SEAT"
                iconColor1: "#ff4444"; iconColor2: "#ff6644"
                type: "seat"
            }

            Item { Layout.fillWidth: true }

            // -- Circulation: two-mode switch (recirculate <-> fresh air) --
            // Slides between the two modes rather than toggling on/off --
            // circulation has no "off", it's always one mode or the other.
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                Text {
                    text: "AIR"
                    color: climateCard.colorTextSubtle
                    font.pixelSize: 11; font.bold: true; font.letterSpacing: 1
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    id: circContainer
                    width: 124; height: 40; radius: 20
                    color: climateCard.colorSurface
                    border.color: climateCard.colorStroke
                    border.width: 1
                    Layout.alignment: Qt.AlignHCenter
                    enabled: climateCard.systemOn
                    opacity: climateCard.systemOn ? 1.0 : 0.4
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

                    // Sliding indicator marks the active mode (left=recirc, right=fresh)
                    Rectangle {
                        id: circIndicator
                        width: circContainer.width / 2 - 4
                        height: circContainer.height - 4
                        y: 2
                        x: 2 + (climateCard.circulationExternal ? 1 : 0) * (circContainer.width / 2)
                        radius: 18
                        color: Qt.rgba(climateCard.colorAccent.r, climateCard.colorAccent.g, climateCard.colorAccent.b, 0.25)
                        border.color: Qt.rgba(climateCard.colorAccent.r, climateCard.colorAccent.g, climateCard.colorAccent.b, 0.50)
                        border.width: 1
                        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }
                    }

                    Row {
                        anchors.fill: parent

                        // Recirculate (internal)
                        Item {
                            width: parent.width / 2; height: parent.height
                            Image {
                                id: recircIcon; anchors.centerIn: parent
                                width: 24; height: 24
                                source: "qrc:/Assets/Climate/iconRecirculation.svg"
                                sourceSize: Qt.size(48, 48); mipmap: true
                                fillMode: Image.PreserveAspectFit; visible: false
                            }
                            MultiEffect {
                                source: recircIcon; anchors.fill: recircIcon
                                colorization: 1.0; brightness: 1.0
                                colorizationColor: !climateCard.circulationExternal ? climateCard.colorTextPrimary : climateCard.colorAccent
                                opacity: !climateCard.circulationExternal ? 1.0 : 0.45
                                Behavior on opacity           { NumberAnimation { duration: 200 } }
                                Behavior on colorizationColor { ColorAnimation  { duration: 200 } }
                            }
                            MouseArea { anchors.fill: parent; onClicked: climateCard.circulationExternal = false }
                        }

                        // Fresh air (external)
                        Item {
                            width: parent.width / 2; height: parent.height
                            Image {
                                id: freshIcon; anchors.centerIn: parent
                                width: 24; height: 24
                                source: "qrc:/Assets/Climate/iconExternalCirculation.svg"
                                sourceSize: Qt.size(48, 48); mipmap: true
                                fillMode: Image.PreserveAspectFit; visible: false
                            }
                            MultiEffect {
                                source: freshIcon; anchors.fill: freshIcon
                                colorization: 1.0; brightness: 1.0
                                colorizationColor: climateCard.circulationExternal ? climateCard.colorTextPrimary : climateCard.colorAccent
                                opacity: climateCard.circulationExternal ? 1.0 : 0.45
                                Behavior on opacity           { NumberAnimation { duration: 200 } }
                                Behavior on colorizationColor { ColorAnimation  { duration: 200 } }
                            }
                            MouseArea { anchors.fill: parent; onClicked: climateCard.circulationExternal = true }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            HvacflowButton {
                label: "PASSENGER SEAT"
                iconColor1: "#ff4444"; iconColor2: "#ff6644"
                type: "seat"
                mirrorIcon: true
            }

            Item { Layout.preferredWidth: 12 }
        }
        }
    }
}
