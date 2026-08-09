import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

// -----------------------------------------------------------------------------
// SeatCard
//
// Driver and passenger seat position. Tilt only, for now.
//
// ponytail: tilt is QML-only state, exactly like ClimateCard's acOn/fanSpeed and
// the seat-heat levels in HvacflowButton. Wire it to CanController (or a
// SeatController singleton) when there is an actuator on the other end -- the
// CAN layer is generic frameReceived/send today, with no seat IDs defined.
// -----------------------------------------------------------------------------
Item {
    id: seatCard

    // Theme tokens from mainRoot
    property bool isNightMode: typeof mainRoot !== "undefined" ? mainRoot.isNightMode : true
    property int radiusLarge: typeof mainRoot !== "undefined" ? mainRoot.radiusLarge : 28
    property int radiusSmall: typeof mainRoot !== "undefined" ? mainRoot.radiusSmall : 16
    property color colorSurface: typeof mainRoot !== "undefined" ? mainRoot.colorSurface : Qt.rgba(0.06, 0.04, 0.10, 0.65)
    property color colorSurfaceAlt: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceAlt : Qt.rgba(0.09, 0.07, 0.15, 0.75)
    property color colorSurfaceInset: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceInset : Qt.rgba(0.17, 0.15, 0.22, 0.5)
    property color colorStroke: typeof mainRoot !== "undefined" ? mainRoot.colorStroke : Qt.rgba(1, 1, 1, 0.15)
    property color colorTextPrimary: typeof mainRoot !== "undefined" ? mainRoot.colorTextPrimary : "#ffffff"
    property color colorTextMuted: typeof mainRoot !== "undefined" ? mainRoot.colorTextMuted : "#eae6f8"
    property color colorTextSubtle: typeof mainRoot !== "undefined" ? mainRoot.colorTextSubtle : "#b8b2c8"
    property color colorAccent: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"

    // Expose both angles for home quick controls, the way ClimateCard exposes
    // driverTemperature / passengerTemperature.
    property alias driverTilt: driverZone.tilt
    property alias passengerTilt: passengerZone.tilt

    // Named stops, shared by the slider ticks and the preset chips so the two
    // can't drift apart. Every deg must be a multiple of the slider's stepSize.
    readonly property var presets: [
        { name: "Upright", deg: 0 },
        { name: "Comfort", deg: 20 },
        { name: "Recline", deg: 40 }
    ]

    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: seatCard.radiusLarge
        color: seatCard.colorSurface
        border.color: seatCard.colorStroke
        border.width: 1
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 16

        SeatZone {
            id: driverZone
            label: "DRIVER"
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        SeatZone {
            id: passengerZone
            label: "PASSENGER"
            mirrored: true          // matches HvacflowButton's mirrorIcon convention
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    // -------------------------------------------------------------------------
    // One seat: header + angle, silhouette, slider, presets.
    // -------------------------------------------------------------------------
    component SeatZone: Rectangle {
        id: zone

        property string label: "DRIVER"
        property bool mirrored: false
        // Driven by the slider, which clamps to [from, to] itself -- the step
        // buttons and presets need no bounds check of their own.
        readonly property int tilt: Math.round(zSlider.value)

        radius: seatCard.radiusLarge - 8
        color: seatCard.colorSurfaceAlt
        border.color: seatCard.colorStroke
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            // -- Header ---------------------------------------------------------
            // ponytail: no numeric readout. Recline isn't something anyone thinks
            // about in degrees, and with no seat position on CAN the number would
            // be invented by the slider anyway. Position is carried by the seat
            // angle, the slider handle against its ticks, and the active chip.
            Text {
                text: zone.label
                color: seatCard.colorTextSubtle
                font.pixelSize: 12
                font.bold: true
                font.letterSpacing: 1.4
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: seatCard.colorStroke
            }

            // -- Seat silhouette, side-on --------------------------------------
            // Split out of Assets/Climate/heatedSeat-level0.svg, which is 10
            // separate paths: headrest + backrest (recline together), cushion +
            // hinge knob + base (fixed), and 3 heat-wave paths level0 keeps
            // commented out. Both halves share one viewBox cropped to the artwork, so
            // they overlay exactly in a container of the same aspect ratio.
            Item {
                id: stage
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Measured off the path data: at 45 deg the backrest sweeps
                // 0.47 x the art width past the hinge side. Reserve that, or the
                // headrest leaves the panel. The gap it leaves on the upright
                // seat is the room it reclines into, and it mirrors with the
                // passenger so the two panels stay symmetric.
                readonly property real sweep: 0.47
                readonly property real blockW: seatArt.width * (1 + sweep)

                Item {
                    id: seatArt
                    // Fit to whichever axis runs out first, sweep included.
                    width: Math.min(stage.width / (1 + stage.sweep),
                                    stage.height * 1581 / 1747)
                    height: Math.round(width * 1747 / 1581)
                    x: (stage.width - stage.blockW) / 2
                       + (zone.mirrored ? 0 : width * stage.sweep)
                    y: (stage.height - height) / 2

                    // Hinge knob centre, as a fraction of the source canvas.
                    readonly property real pivotX: zone.mirrored ? 1 - 0.3005 : 0.3005
                    readonly property real pivotY: 0.8043

                    // Cushion, hinge knob and base -- fixed.
                    Image {
                        id: baseImg
                        anchors.fill: parent
                        source: "qrc:/Assets/Seat/seatBase.svg"
                        sourceSize: Qt.size(640, 707)
                        fillMode: Image.PreserveAspectFit
                        mirror: zone.mirrored
                        mipmap: true
                        visible: false
                    }
                    MultiEffect {
                        source: baseImg
                        anchors.fill: baseImg
                        colorization: 1.0
                        brightness: 1.0
                        colorizationColor: seatCard.colorAccent
                    }

                    Image {
                        id: backImg
                        anchors.fill: parent
                        source: "qrc:/Assets/Seat/seatBackrest.svg"
                        sourceSize: Qt.size(640, 707)
                        fillMode: Image.PreserveAspectFit
                        mirror: zone.mirrored
                        mipmap: true
                        visible: false
                    }

                    // ponytail: skipped a ghost of the upright backrest behind the
                    // live one -- a filled silhouette at low opacity reads as a
                    // second seat, not a reference mark. Would need an outline-only
                    // asset to work.

                    // Live backrest -- reclines about the hinge knob. Qt rotates
                    // clockwise, so an unmirrored (right-facing) seat reclines
                    // negative and the mirrored one positive.
                    MultiEffect {
                        source: backImg
                        anchors.fill: backImg
                        colorization: 1.0
                        brightness: 1.0
                        colorizationColor: seatCard.colorAccent

                        transform: Rotation {
                            origin.x: seatArt.width * seatArt.pivotX
                            origin.y: seatArt.height * seatArt.pivotY
                            angle: zone.mirrored ? zone.tilt : -zone.tilt
                            // Constant velocity, not constant duration -- a motor
                            // takes longer for longer travel, so an Upright ->
                            // Recline jump must not land in the same time as a
                            // one-step nudge. ~65ms for a step, ~600ms end to end.
                            Behavior on angle { SmoothedAnimation { velocity: 75 } }
                        }
                    }
                }
            }

            // -- Step buttons + slider ------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                StepBtn { symbol: "−"; onTapped: zSlider.value -= zSlider.stepSize }

                Slider {
                    id: zSlider
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: 24   // custom handle/bg leave ~0 clickable height otherwise
                    from: 0
                    to: 45
                    // 5 deg, not 1: with the number gone, a one-degree tap reads as
                    // a dead button. Every preset deg must stay a multiple of this
                    // or the chips stop matching exactly.
                    stepSize: 5
                    value: 0

                    background: Rectangle {
                        x: 0
                        y: (parent.height - height) / 2
                        width: parent.width
                        height: 4
                        radius: 2
                        color: seatCard.colorStroke

                        // Preset stops. The handle rides over them, so the mark
                        // under it is simply covered -- no active state to track.
                        Repeater {
                            model: seatCard.presets
                            delegate: Rectangle {
                                required property var modelData
                                width: 2; height: 10; radius: 1
                                x: (modelData.deg - zSlider.from) / (zSlider.to - zSlider.from)
                                   * (parent.width - width)
                                y: (parent.height - height) / 2
                                color: seatCard.colorStroke
                            }
                        }

                        Rectangle {
                            width: parent.width * zSlider.visualPosition
                            height: parent.height
                            radius: parent.radius
                            color: seatCard.colorAccent
                        }
                    }
                    handle: Rectangle {
                        x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                        width: 16
                        height: 16
                        radius: 8
                        color: seatCard.colorSurface
                        border.color: seatCard.colorAccent
                        border.width: 2
                    }
                }

                StepBtn { symbol: "+"; onTapped: zSlider.value += zSlider.stepSize }
            }

            // -- Presets ---------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: seatCard.presets
                    delegate: PresetChip {
                        required property var modelData
                        label: modelData.name
                        active: zone.tilt === modelData.deg
                        onPicked: zSlider.value = modelData.deg
                    }
                }
            }
        }
    }

    // Square tap target for the -/+ steps. MapActionsPanel does the same by hand;
    // Main.qml's HomeChevronBtn is an inline component scoped to that file.
    component StepBtn: Rectangle {
        id: stepBtn
        property string symbol: "+"
        signal tapped()

        Layout.preferredWidth: 42
        Layout.preferredHeight: 42
        radius: seatCard.radiusSmall
        color: stepMa.pressed ? seatCard.colorSurface : seatCard.colorSurfaceInset
        border.color: stepMa.pressed ? seatCard.colorAccent : seatCard.colorStroke
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: stepBtn.symbol
            color: seatCard.colorTextPrimary
            font.pixelSize: 20
        }

        MouseArea {
            id: stepMa
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: stepBtn.tapped()
        }
    }

    component PresetChip: Rectangle {
        id: chip
        property string label: ""
        property bool active: false
        signal picked()

        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: 17
        color: chip.active
               ? Qt.rgba(seatCard.colorAccent.r, seatCard.colorAccent.g, seatCard.colorAccent.b, 0.25)
               : seatCard.colorSurfaceInset
        border.color: chip.active ? seatCard.colorAccent : seatCard.colorStroke
        border.width: 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        Text {
            anchors.centerIn: parent
            text: chip.label
            color: chip.active ? seatCard.colorTextPrimary : seatCard.colorTextSubtle
            font.pixelSize: 12
            font.weight: chip.active ? Font.DemiBold : Font.Normal
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.picked()
        }
    }
}
