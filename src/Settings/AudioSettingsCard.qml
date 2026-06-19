import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Sylph.Settings 1.0

Item {
    id: root

    property int radiusSmall: typeof mainRoot !== "undefined" ? mainRoot.radiusSmall : 16
    property color colorSurfaceAlt: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceAlt : "#dd141021"
    property color colorSurface: typeof mainRoot !== "undefined" ? mainRoot.colorSurface : "#c80e0a17"
    property color colorStroke: typeof mainRoot !== "undefined" ? mainRoot.colorStroke : "#2bffffff"
    property color colorTextPrimary: typeof mainRoot !== "undefined" ? mainRoot.colorTextPrimary : "#ffffff"
    property color colorTextMuted: typeof mainRoot !== "undefined" ? mainRoot.colorTextMuted : "#eae6f8"
    property color colorTextSubtle: typeof mainRoot !== "undefined" ? mainRoot.colorTextSubtle : "#b8b2c8"
    property color colorAccent: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"
    property color colorAccentAlt: typeof mainRoot !== "undefined" ? mainRoot.colorAccentAlt : "#7de2ff"
    property bool isNightMode: typeof mainRoot !== "undefined" ? mainRoot.isNightMode : true

    // Theme-aware surfaces for the speaker-simulator module
    readonly property color simSurface: isNightMode ? Qt.rgba(0.12, 0.13, 0.18, 0.95) : Qt.rgba(0.90, 0.88, 0.95, 0.95)
    readonly property color simBody: isNightMode ? "#2a2b36" : "#e4e0ee"
    readonly property color simStroke: isNightMode ? "#4a4b59" : "#b8b2c8"
    readonly property color simText: isNightMode ? "#ffffff" : "#1a1824"

    // Audio equalizer state
    property int bass: 50
    property int treble: 50
    property int subwoofer: 50

    // Speaker balance/fader state (-100 = full left/front, +100 = full right/rear)
    property int balance: 0
    property int fader: 0

    // Reusable styled slider component
    component AudioSlider: RowLayout {
        id: sliderRow
        property string label: ""
        property string icon: ""
        property int value: 50
        property color accentColor: root.colorAccent
        signal moved(int newValue)

        Layout.fillWidth: true
        spacing: 10

        Text {
            text: sliderRow.icon
            font.pixelSize: 16
            color: root.colorTextSubtle
            Layout.preferredWidth: 22
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: sliderRow.label
            color: root.colorTextPrimary
            font.pixelSize: 13
            font.bold: true
            Layout.preferredWidth: 75
        }

        Slider {
            id: innerSlider
            Layout.fillWidth: true
            from: 0
            to: 100
            value: sliderRow.value
            onMoved: sliderRow.moved(Math.round(value))

            background: Rectangle {
                x: innerSlider.leftPadding
                y: innerSlider.topPadding + innerSlider.availableHeight / 2 - height / 2
                implicitWidth: 200
                implicitHeight: 6
                width: innerSlider.availableWidth
                height: implicitHeight
                radius: 3
                color: root.colorStroke

                Rectangle {
                    width: innerSlider.visualPosition * parent.width
                    height: parent.height
                    radius: 3
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: root.isNightMode ? "#4a4560" : "#b3a9d6"
                        }
                        GradientStop {
                            position: 1.0
                            color: sliderRow.accentColor
                        }
                    }
                }
            }

            handle: Rectangle {
                x: innerSlider.leftPadding + innerSlider.visualPosition * (innerSlider.availableWidth - width)
                y: innerSlider.topPadding + innerSlider.availableHeight / 2 - height / 2
                implicitWidth: 18
                implicitHeight: 18
                radius: 9
                color: innerSlider.pressed ? sliderRow.accentColor : root.colorTextPrimary
                border.color: root.colorStroke
                border.width: 2

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
        }

        Text {
            text: sliderRow.value
            color: sliderRow.accentColor
            font.pixelSize: 13
            font.bold: true
            Layout.preferredWidth: 30
            horizontalAlignment: Text.AlignRight
        }
    }

    // -- DYNAMIC SPEAKER SIMULATOR NODE --
    component SpeakerNode: Item {
        id: speakerRoot
        property bool isRight: false
        property bool isRear: false
        property color accent: root.colorAccentAlt

        // Corrected Automotive DSP Math
        property real volumeFactor: {
            var bal = AudioSettingsController.balance;
            var fad = AudioSettingsController.fader;

            // Center (0) = 1.0 volume.
            // Shifting Right (+bal) drops Left volume. Shifting Left (-bal) drops Right volume.
            var xVol = isRight ? (bal < 0 ? (100 + bal) / 100.0 : 1.0) : (bal > 0 ? (100 - bal) / 100.0 : 1.0);

            var yVol = isRear ? (fad < 0 ? (100 + fad) / 100.0 : 1.0) : (fad > 0 ? (100 - fad) / 100.0 : 1.0);

            return xVol * yVol;
        }

        width: 54
        height: 64

        // Main Pill Box
        Rectangle {
            id: pillBg
            width: 54
            height: 58
            radius: 14
            color: root.simSurface
            border.color: root.isNightMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.10)
            border.width: 1

            // Full Circle Container
            Item {
                anchors.top: parent.top
                anchors.topMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                width: 32
                height: 32

                // 1. Animated Pulsing Ring (Behind)
                Rectangle {
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    radius: 16
                    color: "transparent"
                    border.color: speakerRoot.accent
                    border.width: 2

                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        running: speakerRoot.volumeFactor > 0.05
                        NumberAnimation {
                            from: 1.0
                            to: 1.6
                            duration: 1200
                            easing.type: Easing.OutSine
                        }
                    }
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: speakerRoot.volumeFactor > 0.05
                        NumberAnimation {
                            from: 0.8 * speakerRoot.volumeFactor
                            to: 0.0
                            duration: 1200
                            easing.type: Easing.OutSine
                        }
                    }
                }

                // 2. Static Background Ring
                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: "transparent"
                    border.color: Qt.rgba(speakerRoot.accent.r, speakerRoot.accent.g, speakerRoot.accent.b, 0.3)
                    border.width: 2
                }

                // 3. Liquid Fill (Clips a full circle from the bottom up)
                Item {
                    anchors.bottom: parent.bottom
                    width: 32
                    height: 32 * speakerRoot.volumeFactor
                    clip: true

                    Behavior on height {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCirc
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: 32
                        height: 32
                        radius: 16
                        color: Qt.rgba(speakerRoot.accent.r, speakerRoot.accent.g, speakerRoot.accent.b, 0.8)
                    }
                }
            }

            // Percentage Text
            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(speakerRoot.volumeFactor * 100) + "%"
                color: root.simText
                font.pixelSize: 11
                font.bold: true
                opacity: speakerRoot.volumeFactor > 0.05 ? 1.0 : 0.4

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }
            }
        }

        // Small Downward Triangle Pointer
        Canvas {
            id: triangleCanvas
            anchors.top: pillBg.bottom
            anchors.topMargin: -1
            anchors.horizontalCenter: parent.horizontalCenter
            width: 12
            height: 6
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(width, 0);
                ctx.lineTo(width / 2, height);
                ctx.closePath();
                ctx.fillStyle = root.simSurface;
                ctx.fill();

                // Outer border lines for the triangle
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(width / 2, height);
                ctx.lineTo(width, 0);
                ctx.strokeStyle = root.isNightMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.10);
                ctx.lineWidth = 1;
                ctx.stroke();
            }
            Connections {
                target: root
                function onIsNightModeChanged() { triangleCanvas.requestPaint() }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        // -- SECTION HEADER --
        Text {
            text: "Audio"
            color: colorTextPrimary
            font.pixelSize: 20
            font.bold: true
        }

        // -- EQUALIZER SECTION --
        GlassPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: 190
            radiusSize: radiusSmall

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Equalizer"
                        color: colorTextPrimary
                        font.pixelSize: 15
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    Button {
                        text: "Reset"
                        onClicked: AudioSettingsController.resetToCenter()
                        background: Rectangle {
                            radius: 10
                            color: parent.down ? colorAccent : colorSurfaceAlt
                            border.color: colorStroke
                            border.width: 1
                        }
                        contentItem: Text {
                            text: parent.text
                            color: parent.down ? "#c80e0a17" : colorTextMuted
                            font.pixelSize: 11
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                AudioSlider {
                    label: "Bass"
                    icon: "LO"
                    value: AudioSettingsController.bass
                    accentColor: "#ff8e6b"
                    onMoved: function (v) {
                        AudioSettingsController.setBass(v);
                    }
                }

                AudioSlider {
                    label: "Treble"
                    icon: "HI"
                    value: AudioSettingsController.treble
                    accentColor: root.colorAccentAlt
                    onMoved: function (v) {
                        AudioSettingsController.setTreble(v);
                    }
                }

                AudioSlider {
                    label: "Subwoofer"
                    icon: "SUB"
                    value: AudioSettingsController.subwoofer
                    accentColor: "#c58aff"
                    onMoved: function (v) {
                        AudioSettingsController.setSubwoofer(v);
                    }
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

        // -- SPEAKER BALANCE / FADER SECTION --
        GlassPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radiusSize: radiusSmall

            RowLayout {
                anchors.fill: parent
                spacing: 20

                // -- LEFT: MINIMALIST SIMULATOR --
                Item {
                    Layout.preferredWidth: 190
                    Layout.fillHeight: true

                    // Direction Labels
                    Text {
                        anchors.top: parent.top
                        anchors.topMargin: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "FRONT"
                        color: root.colorTextPrimary
                        font.bold: true
                        font.pixelSize: 11
                        font.letterSpacing: 1.5
                    }

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "REAR"
                        color: root.colorTextPrimary
                        font.bold: true
                        font.pixelSize: 11
                        font.letterSpacing: 1.5
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "LEFT"
                        color: root.colorTextPrimary
                        font.bold: true
                        font.pixelSize: 11
                        font.letterSpacing: 1.5
                        rotation: -90
                        transformOrigin: Item.Center
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "RIGHT"
                        color: root.colorTextPrimary
                        font.bold: true
                        font.pixelSize: 11
                        font.letterSpacing: 1.5
                        rotation: 90
                        transformOrigin: Item.Center
                    }

                    // Dark Container Box
                    Rectangle {
                        id: carBody
                        anchors.centerIn: parent
                        width: 136
                        height: parent.height - 32
                        radius: 20
                        color: root.simBody
                        border.color: root.isNightMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.12)
                        border.width: 1.5

                        // Spatial layout margins
                        property real minMarginX: 8
                        property real minMarginY: 18

                        // Dashed Crosshairs Canvas
                        Canvas {
                            id: crosshairCanvas
                            anchors.fill: parent
                            Connections {
                                target: root
                                function onIsNightModeChanged() { crosshairCanvas.requestPaint() }
                            }
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.strokeStyle = root.simStroke;
                                ctx.lineWidth = 2.0;
                                ctx.setLineDash([6, 6]);

                                // Connect perfectly to the centers of the speaker pills
                                var startX = parent.minMarginX + 27;
                                var startY = parent.minMarginY + 29;

                                ctx.beginPath();
                                // Vertical Line
                                ctx.moveTo(width / 2, startY);
                                ctx.lineTo(width / 2, height - startY);
                                // Horizontal Line
                                ctx.moveTo(startX, height / 2);
                                ctx.lineTo(width - startX, height / 2);
                                ctx.stroke();
                            }
                        }

                        // 4 Speaker Nodes
                        SpeakerNode {
                            anchors.left: parent.left
                            anchors.leftMargin: carBody.minMarginX
                            anchors.top: parent.top
                            anchors.topMargin: carBody.minMarginY
                            isRight: false
                            isRear: false
                        }
                        SpeakerNode {
                            anchors.right: parent.right
                            anchors.rightMargin: carBody.minMarginX
                            anchors.top: parent.top
                            anchors.topMargin: carBody.minMarginY
                            isRight: true
                            isRear: false
                        }
                        SpeakerNode {
                            anchors.left: parent.left
                            anchors.leftMargin: carBody.minMarginX
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: carBody.minMarginY
                            isRight: false
                            isRear: true
                        }
                        SpeakerNode {
                            anchors.right: parent.right
                            anchors.rightMargin: carBody.minMarginX
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: carBody.minMarginY
                            isRight: true
                            isRear: true
                        }

                        // Interactive MouseArea to tap/drag the balance and fader position directly on the grid
                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            preventStealing: true

                            function updateFromMouse(mouse) {
                                var centerX = width / 2;
                                var centerY = height / 2;

                                // Note: Uses 64 for max height scaling math since SpeakerNode is now 64px tall
                                var maxRangeX = (width - 2 * carBody.minMarginX - 54) / 2;
                                var maxRangeY = (height - 2 * carBody.minMarginY - 64) / 2;

                                var relX = Math.max(-maxRangeX, Math.min(maxRangeX, mouse.x - centerX));
                                var relY = Math.max(-maxRangeY, Math.min(maxRangeY, mouse.y - centerY));

                                var bal = Math.round((relX / maxRangeX) * 100);
                                var fad = Math.round((relY / maxRangeY) * 100);

                                AudioSettingsController.setBalance(bal);
                                AudioSettingsController.setFader(fad);
                            }

                            onPressed: mouse => updateFromMouse(mouse)
                            onPositionChanged: mouse => updateFromMouse(mouse)
                        }

                        // Interactive Crosshair Dot
                        Rectangle {
                            id: crosshair
                            width: 20
                            height: 20
                            radius: 10
                            color: root.colorAccentAlt

                            // Maps from -100 to 100 across the bounded speaker centers
                            x: (carBody.width - width) / 2 + (AudioSettingsController.balance / 100.0) * ((carBody.width - 2 * carBody.minMarginX - 54) / 2)
                            y: (carBody.height - height) / 2 + (AudioSettingsController.fader / 100.0) * ((carBody.height - 2 * carBody.minMarginY - 64) / 2)

                            Behavior on x {
                                enabled: !dragArea.pressed
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutCirc
                                }
                            }
                            Behavior on y {
                                enabled: !dragArea.pressed
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutCirc
                                }
                            }
                        }
                    }
                }

                // -- RIGHT: BALANCE/FADER SLIDERS --
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14

                    // Balance slider
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Balance"
                                color: colorTextPrimary
                                font.pixelSize: 13
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            Text {
                                text: AudioSettingsController.balance === 0 ? "Center" : (AudioSettingsController.balance < 0 ? "L " + Math.abs(AudioSettingsController.balance) : "R " + AudioSettingsController.balance)
                                color: colorAccentAlt
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "L"
                                color: colorTextSubtle
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Slider {
                                id: balanceSlider
                                Layout.fillWidth: true
                                from: -100
                                to: 100
                                value: AudioSettingsController.balance
                                onMoved: AudioSettingsController.setBalance(Math.round(value))

                                background: Rectangle {
                                    x: balanceSlider.leftPadding
                                    y: balanceSlider.topPadding + balanceSlider.availableHeight / 2 - height / 2
                                    implicitHeight: 6
                                    width: balanceSlider.availableWidth
                                    height: implicitHeight
                                    radius: 3
                                    color: root.colorStroke
                                    Rectangle {
                                        x: parent.width / 2 - 1
                                        y: -2
                                        width: 2
                                        height: parent.height + 4
                                        color: root.colorStroke
                                    }
                                }
                                handle: Rectangle {
                                    x: balanceSlider.leftPadding + balanceSlider.visualPosition * (balanceSlider.availableWidth - width)
                                    y: balanceSlider.topPadding + balanceSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 18
                                    implicitHeight: 18
                                    radius: 9
                                    color: balanceSlider.pressed ? root.colorAccentAlt : root.colorTextPrimary
                                    border.color: root.colorStroke
                                    border.width: 2
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }
                                }
                            }
                            Text {
                                text: "R"
                                color: colorTextSubtle
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }

                    // Fader slider
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Fader"
                                color: colorTextPrimary
                                font.pixelSize: 13
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            Text {
                                text: AudioSettingsController.fader === 0 ? "Center" : (AudioSettingsController.fader < 0 ? "Front " + Math.abs(AudioSettingsController.fader) : "Rear " + AudioSettingsController.fader)
                                color: "#c58aff"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "F"
                                color: colorTextSubtle
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Slider {
                                id: faderSlider
                                Layout.fillWidth: true
                                from: -100
                                to: 100
                                value: AudioSettingsController.fader
                                onMoved: AudioSettingsController.setFader(Math.round(value))

                                background: Rectangle {
                                    x: faderSlider.leftPadding
                                    y: faderSlider.topPadding + faderSlider.availableHeight / 2 - height / 2
                                    implicitHeight: 6
                                    width: faderSlider.availableWidth
                                    height: implicitHeight
                                    radius: 3
                                    color: root.colorStroke
                                    Rectangle {
                                        x: parent.width / 2 - 1
                                        y: -2
                                        width: 2
                                        height: parent.height + 4
                                        color: root.colorStroke
                                    }
                                }
                                handle: Rectangle {
                                    x: faderSlider.leftPadding + faderSlider.visualPosition * (faderSlider.availableWidth - width)
                                    y: faderSlider.topPadding + faderSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 18
                                    implicitHeight: 18
                                    radius: 9
                                    color: faderSlider.pressed ? "#c58aff" : root.colorTextPrimary
                                    border.color: root.colorStroke
                                    border.width: 2
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }
                                }
                            }
                            Text {
                                text: "R"
                                color: colorTextSubtle
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }

                    Button {
                        text: "Reset to Center"
                        Layout.alignment: Qt.AlignHCenter
                        onClicked: {
                            AudioSettingsController.setBalance(0);
                            AudioSettingsController.setFader(0);
                        }
                        background: Rectangle {
                            radius: 12
                            color: parent.down ? colorAccent : colorSurfaceAlt
                            border.color: colorStroke
                            border.width: 1
                        }
                        contentItem: Text {
                            text: parent.text
                            color: parent.down ? "#c80e0a17" : colorTextMuted
                            font.pixelSize: 12
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
