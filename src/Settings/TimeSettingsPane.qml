import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Sylph.Settings 1.0

// Date & Time settings: live preview, display format (24h / seconds), and two
// independent overrides -- the time zone and the device time.
// The device-time override is display-only, persisted via QtCore Settings in
// Main.qml. The TIME ZONE is not: picking one also repoints /etc/localtime through
// TimeZoneController, so logs, chrony and anything else on the guest agree with
// what the dash shows, and it survives a reboot.
Item {
    id: root

    property int radiusSmall: typeof mainRoot !== "undefined" ? mainRoot.radiusSmall : 16
    property color colorSurfaceAlt: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceAlt : "#dd141021"
    property color colorSurfaceInset: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceInset : Qt.rgba(0.17, 0.15, 0.22, 0.5)
    property color colorStroke: typeof mainRoot !== "undefined" ? mainRoot.colorStroke : "#2bffffff"
    property color colorTextPrimary: typeof mainRoot !== "undefined" ? mainRoot.colorTextPrimary : "#ffffff"
    property color colorTextSubtle: typeof mainRoot !== "undefined" ? mainRoot.colorTextSubtle : "#b8b2c8"
    property color colorAccent: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"
    property color colorAccentAlt: typeof mainRoot !== "undefined" ? mainRoot.colorAccentAlt : "#7de2ff"

    property bool use24Hour:   typeof mainRoot !== "undefined" ? mainRoot.clockUse24Hour   : true
    property bool showSeconds: typeof mainRoot !== "undefined" ? mainRoot.clockShowSeconds : false
    property bool timeAuto:    typeof mainRoot !== "undefined" ? mainRoot.clockTimeAuto : true
    property bool zoneAuto:    typeof mainRoot !== "undefined" ? mainRoot.clockZoneAuto : true
    property string zoneId:    typeof mainRoot !== "undefined" ? mainRoot.clockZoneId : ""

    // Ticking clock for the live preview (honors the overrides)
    property var now: effDate()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = root.effDate() }

    function effDate()   { return (typeof mainRoot !== "undefined") ? mainRoot.effectiveDate() : new Date() }
    function effOffMin() { return (typeof mainRoot !== "undefined") ? mainRoot.effectiveOffsetMin() : -(new Date().getTimezoneOffset()) }

    function timeFmt() {
        return root.use24Hour
            ? (root.showSeconds ? "HH:mm:ss" : "HH:mm")
            : (root.showSeconds ? "h:mm:ss AP" : "h:mm AP")
    }
    function offLabel(min) {
        var s = min >= 0 ? "+" : "-"
        var a = Math.abs(min), h = Math.floor(a / 60), m = a % 60
        return "GMT" + s + (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
    }
    function pad(n) { return (n < 10 ? "0" : "") + n }

    // -- Override mutations (refresh `now` for instant feedback) ---------------
    function nudge(ms) {
        if (typeof mainRoot === "undefined") return
        mainRoot.clockManualDeltaMs += ms
        root.now = effDate()
    }
    // Picking a zone does two things: repoint the SYSTEM zone (persists, and every
    // other process on the guest follows), and record the id so this app renders it
    // without waiting for a restart. If the system write fails - /etc read-only, or
    // no tzdata for that id - the display is left alone rather than lying about it.
    function applyZone(id) {
        if (typeof mainRoot === "undefined" || id === "") return
        if (!TimeZoneController.setZone(id)) {
            console.warn("[Time] could not set system zone to", id)
            return
        }
        mainRoot.clockZoneId = id
        root.now = effDate()
    }
    function setTimeAuto(auto) {
        if (typeof mainRoot === "undefined") return
        mainRoot.clockTimeAuto = auto
        mainRoot.clockManualDeltaMs = 0   // manual time starts from the current time
        root.now = effDate()
    }
    function setZoneAuto(auto) {
        if (typeof mainRoot === "undefined") return
        mainRoot.clockZoneAuto = auto
        if (!auto && mainRoot.clockZoneId === "")   // seed the picker from the system zone
            mainRoot.clockZoneId = TimeZoneController.zoneId
        root.now = effDate()
    }

    // -- Toggle row (title + optional subtitle + switch) --
    component ToggleRow: Rectangle {
        id: trow
        property string title: ""
        property string subtitle: ""
        property bool on: false
        property color accent: colorAccent
        signal toggled(bool c)
        Layout.fillWidth: true
        Layout.preferredHeight: subtitle === "" ? 56 : 60
        radius: radiusSmall
        color: colorSurfaceInset
        border.color: colorStroke
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
            ColumnLayout {
                spacing: 1
                Text { text: trow.title; color: colorTextPrimary; font.pixelSize: 14; font.bold: true }
                Text { visible: trow.subtitle !== ""; text: trow.subtitle; color: colorTextSubtle; font.pixelSize: 12 }
            }
            Item { Layout.fillWidth: true }   // spacer -- pins the switch to the right edge
            GlassSwitch { checked: trow.on; checkedColor: trow.accent; onToggled: (c) => trow.toggled(c) }
        }
    }

    // -- Small +/- button --
    component StepBtn: Rectangle {
        signal clicked()
        property string glyph: ""
        width: 38; height: 38; radius: 10
        color: sbMa.pressed ? Qt.rgba(colorAccent.r, colorAccent.g, colorAccent.b, 0.28) : colorSurfaceAlt
        border.color: colorStroke; border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Text { anchors.centerIn: parent; text: glyph; color: colorTextPrimary; font.pixelSize: 20; font.bold: true }
        MouseArea { id: sbMa; anchors.fill: parent; onClicked: parent.clicked() }
    }

    // -- Labelled dropdown row --
    // Two of these (Region, then City) beat one flat list: tzdata carries ~600 zone
    // ids, which is not a scrollable list anyone can use on a touchscreen.
    component PickerRow: Rectangle {
        id: prow
        property string label: ""
        property var options: []
        property string current: ""
        signal picked(string value)
        Layout.fillWidth: true
        Layout.preferredHeight: 60
        radius: radiusSmall
        color: colorSurfaceInset
        border.color: colorStroke
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
            Text { text: prow.label; color: colorTextPrimary; font.pixelSize: 14; font.bold: true }
            Item { Layout.fillWidth: true }
            ComboBox {
                id: combo
                model: prow.options
                Layout.preferredWidth: 210
                Layout.preferredHeight: 40
                font.pixelSize: 14
                // Assigning `model` resets currentIndex, so re-seat the selection
                // whenever either side changes or the box snaps back to entry 0.
                currentIndex: Math.max(0, prow.options.indexOf(prow.current))
                onModelChanged: currentIndex = Math.max(0, prow.options.indexOf(prow.current))
                onActivated: prow.picked(prow.options[currentIndex])

                contentItem: Text {
                    leftPadding: 10
                    rightPadding: 28
                    text: combo.displayText
                    color: colorAccent
                    font: combo.font
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 10
                    color: colorSurfaceAlt
                    border.color: colorStroke
                    border.width: 1
                }
            }
        }
    }

    // -- Labelled stepper row --
    component Stepper: Rectangle {
        id: srow
        property string label: ""
        property string valueText: ""
        signal dec()
        signal inc()
        Layout.fillWidth: true
        Layout.preferredHeight: 60
        radius: radiusSmall
        color: colorSurfaceInset
        border.color: colorStroke
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
            Text { text: srow.label; color: colorTextPrimary; font.pixelSize: 14; font.bold: true; Layout.fillWidth: true }
            StepBtn { glyph: "−"; onClicked: srow.dec() }
            Text {
                text: srow.valueText
                color: colorAccent
                font.pixelSize: 18
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.minimumWidth: 92
            }
            StepBtn { glyph: "+"; onClicked: srow.inc() }
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: -1   // disable horizontal scrolling
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: parent.width
            spacing: 14

            Text {
                text: "Date & Time"
                color: colorTextPrimary
                font.pixelSize: 20
                font.bold: true
                Layout.bottomMargin: 2
            }

            // -- LIVE PREVIEW --
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 132
                radius: radiusSmall
                color: colorSurfaceAlt
                border.color: colorStroke
                border.width: 1

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatTime(root.now, root.timeFmt())
                        color: colorTextPrimary
                        font.pixelSize: 44
                        font.bold: true
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDate(root.now, "dddd, d MMMM yyyy")
                        color: colorTextSubtle
                        font.pixelSize: 15
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: (root.zoneAuto || root.zoneId === ""
                               ? TimeZoneController.zoneId
                               : root.zoneId) + "  ·  " + root.offLabel(root.effOffMin())
                        color: colorTextSubtle
                        font.pixelSize: 12
                    }
                }
            }

            // ============ TIME ZONE ============
            ToggleRow {
                title: "Set Time Zone Automatically"
                subtitle: "Use the system time zone"
                on: root.zoneAuto
                onToggled: (c) => root.setZoneAuto(c)
            }
            PickerRow {
                id: regionPicker
                visible: !root.zoneAuto
                label: "Region"
                options: TimeZoneController.regions()
                current: TimeZoneController.regionOf(root.zoneId)
                // Region alone is not a zone; jump to the first city in it so the
                // selection is always a valid id rather than a half-picked state.
                onPicked: (r) => {
                    var cities = TimeZoneController.citiesIn(r)
                    if (cities.length > 0)
                        root.applyZone(r === "Other" ? cities[0] : r + "/" + cities[0])
                }
            }
            PickerRow {
                visible: !root.zoneAuto
                label: "City"
                options: TimeZoneController.citiesIn(regionPicker.current)
                current: TimeZoneController.cityOf(root.zoneId)
                onPicked: (c) => {
                    var r = regionPicker.current
                    root.applyZone(r === "Other" ? c : r + "/" + c)
                }
            }

            // ============ TIME ============
            ToggleRow {
                title: "Set Time Automatically"
                subtitle: "Follow the system clock"
                on: root.timeAuto
                onToggled: (c) => root.setTimeAuto(c)
            }
            Stepper {
                visible: !root.timeAuto
                label: "Hour"
                valueText: root.pad(root.now.getHours())
                onDec: root.nudge(-3600000)
                onInc: root.nudge(3600000)
            }
            Stepper {
                visible: !root.timeAuto
                label: "Minute"
                valueText: root.pad(root.now.getMinutes())
                onDec: root.nudge(-60000)
                onInc: root.nudge(60000)
            }

            // -- DIVIDER --
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: colorStroke
                Layout.topMargin: 2
                Layout.bottomMargin: 2
            }

            // ============ FORMAT ============
            ToggleRow {
                title: "24-Hour Time"
                on: root.use24Hour
                onToggled: (c) => {
                    if (typeof mainRoot !== "undefined") mainRoot.clockUse24Hour = c
                    else root.use24Hour = c
                }
            }
            ToggleRow {
                title: "Show Seconds"
                on: root.showSeconds
                onToggled: (c) => {
                    if (typeof mainRoot !== "undefined") mainRoot.clockShowSeconds = c
                    else root.showSeconds = c
                }
            }

            Item { height: 8 }   // bottom breathing room
        }
    }
}
