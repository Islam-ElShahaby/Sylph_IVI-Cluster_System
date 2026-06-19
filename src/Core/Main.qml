import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtCore
import Sylph.Bluetooth 1.0
import Sylph.Radio 1.0
import Sylph.Phone 1.0
import Sylph.Wifi 1.0
import Sylph.LocalMedia 1.0
import Sylph.Core 1.0
import Sylph.Weather 1.0

ApplicationWindow {
    id: mainRoot
    width: 1024
    height: 600
    visible: true
    title: "Sylph"
    color: isNightMode ? "#15141a" : "#f5f4fa"

    property bool isNightMode: computeNight()
    property bool autoNightMode: true
    property bool isSidebarIconOnly: false

    // True when the local clock says it's night (18:00–05:59).
    function computeNight() { var h = new Date().getHours(); return h >= 18 || h < 6 }

    readonly property int baseMargin: 24
    readonly property int radiusLarge: 28
    readonly property int radiusSmall: 16
    readonly property int statusBarHeight: 44
    readonly property int statusBarGap: 16

    // Dynamic color system depending on theme (optimized for glassmorphic contrast)
    readonly property color colorSurface: isNightMode ? Qt.rgba(0.06, 0.04, 0.10, 0.65) : Qt.rgba(0.96, 0.95, 0.98, 0.40)
    readonly property color colorSurfaceAlt: isNightMode ? Qt.rgba(0.09, 0.07, 0.15, 0.75) : Qt.rgba(0.93, 0.91, 0.96, 0.50)
    // Sunken/inset surface for list rows, sliders and nested panels
    readonly property color colorSurfaceInset: isNightMode ? Qt.rgba(0.17, 0.15, 0.22, 0.5) : Qt.rgba(0.85, 0.83, 0.91, 0.55)
    readonly property color colorStroke: isNightMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color colorTextPrimary: isNightMode ? "#ffffff" : "#1a1824"
    readonly property color colorTextMuted: isNightMode ? "#eae6f8" : "#2c283d"
    readonly property color colorTextSubtle: isNightMode ? "#b8b2c8" : "#5c5870"
    readonly property color colorAccent: isNightMode ? "#c0b3ff" : "#6c4ae0"
    readonly property color colorAccentAlt: isNightMode ? "#7de2ff" : "#007ea7"

    font.family: "Helvetica Neue, Arial, sans-serif"

    // The selected media card is the global "active" source. It keeps playing
    // across every tab (home, navigation, etc.) and is controlled by the home
    // dashboard media tile; only switching the media card itself swaps it out.
    readonly property bool isRadioActive: mediaSwiper.currentIndex === 0
    readonly property bool isBluetoothActive: mediaSwiper.currentIndex === 1
    readonly property bool isLocalMediaActive: mediaSwiper.currentIndex === 2

    property int storedBtVolume: 40

    // Clock display prefs (set in Settings > Date & Time), persisted across runs.
    Settings {
        id: clockPrefs
        category: "clock"
        property bool use24Hour: true
        property bool showSeconds: false
        property bool timeAuto: true         // false = manual device time (delta)
        property bool zoneAuto: true         // false = manual GMT offset
        property int  manualOffsetMin: 0      // GMT offset (minutes) when zone is manual
        property real manualDeltaMs: 0        // shift from the real clock when time is manual
    }
    property alias clockUse24Hour:       clockPrefs.use24Hour
    property alias clockShowSeconds:     clockPrefs.showSeconds
    property alias clockTimeAuto:        clockPrefs.timeAuto
    property alias clockZoneAuto:        clockPrefs.zoneAuto
    property alias clockManualOffsetMin: clockPrefs.manualOffsetMin
    property alias clockManualDeltaMs:   clockPrefs.manualDeltaMs

    // Effective "now" honoring the time and zone overrides independently (display
    // only). Returns a Date whose LOCAL fields read as the target wall-clock time,
    // so Qt.formatTime/formatDate render it directly.
    function effectiveDate() {
        var localOffMs  = -(new Date().getTimezoneOffset()) * 60000
        var deltaMs     = clockTimeAuto ? 0 : clockManualDeltaMs
        var targetOffMs = clockZoneAuto ? localOffMs : clockManualOffsetMin * 60000
        return new Date(Date.now() + deltaMs + targetOffMs - localOffMs)
    }
    function effectiveOffsetMin() {
        return clockZoneAuto ? -(new Date().getTimezoneOffset()) : clockManualOffsetMin
    }

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value))
    }

    // -- Home climate bar building blocks --------------------------------
    // Chevron step button (up / down) used inside the compact zone stepper.
    // direction: "up" renders up.svg as-is; "down" rotates it 180°.
    component HomeChevronBtn: Item {
        id: chevBtn
        property string direction: "up"   // "up" | "down"
        signal tapped()
        implicitWidth: 28; implicitHeight: 28

        Image {
            id: chevIcon
            anchors.centerIn: parent
            width: 16; height: 16
            source: "qrc:/Assets/Home_climate/up.svg"
            sourceSize: Qt.size(32, 32)
            fillMode: Image.PreserveAspectFit
            mipmap: true
            visible: false
            rotation: chevBtn.direction === "down" ? 180 : 0
        }
        MultiEffect {
            source: chevIcon
            anchors.fill: chevIcon
            rotation: chevIcon.rotation
            colorization: 1.0
            brightness: chevMa.pressed ? 0.9 : 0.5
            colorizationColor: chevMa.pressed ? colorAccent : colorTextSubtle
            Behavior on colorizationColor { ColorAnimation { duration: 120 } }
            Behavior on brightness       { NumberAnimation  { duration: 120 } }
        }
        MouseArea {
            id: chevMa
            anchors.fill: parent
            anchors.margins: -6
            onClicked: chevBtn.tapped()
        }
    }

    // Compact zone block: icon row + label above, chevron + value + chevron below.
    // Used for both driver and passenger columns in the home climate bar.
    component HomeZoneStepper: Item {
        id: zoneStepper
        property real value: 22
        property bool active: true    // AC on && not auto
        property bool acOn: true      // compressor on -- drives -- display
        property bool coupled: false
        property string iconSource: ""
        property string label: "DRIVER"
        signal stepDown()
        signal stepUp()

        implicitWidth: 130
        implicitHeight: 64
        opacity: !acOn ? 0.45 : (coupled ? 0.55 : 1.0)
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }

        onValueChanged: { if (acOn) zoneValueBump.restart() }

        ColumnLayout {
            anchors.fill: parent
            spacing: 4

            // Icon + label row
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                // Icon (colorized to colorTextSubtle)
                Item {
                    implicitWidth: 16; implicitHeight: 16
                    visible: zoneStepper.iconSource !== ""

                    Image {
                        id: zoneIcon
                        anchors.fill: parent
                        source: zoneStepper.iconSource
                        sourceSize: Qt.size(32, 32)
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        visible: false
                    }
                    MultiEffect {
                        source: zoneIcon
                        anchors.fill: zoneIcon
                        colorization: 1.0
                        brightness: 0.6
                        colorizationColor: colorTextSubtle
                    }
                }

                Text {
                    text: zoneStepper.label
                    color: colorTextSubtle
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.2
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // down  VALUE  up  (chevrons hidden when AC is off)
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                HomeChevronBtn {
                    direction: "down"
                    visible: zoneStepper.acOn
                    enabled: zoneStepper.active
                    onTapped: zoneStepper.stepDown()
                }

                Text {
                    id: zoneValueText
                    // Show "--" when AC (compressor) is off
                    text: zoneStepper.acOn
                          ? (zoneStepper.value % 1 === 0
                             ? zoneStepper.value.toFixed(0)
                             : zoneStepper.value.toFixed(1)) + "°"
                          : "--"
                    color: zoneStepper.acOn ? colorTextPrimary : colorTextSubtle
                    font.pixelSize: 30
                    font.bold: true
                    transformOrigin: Item.Center
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                HomeChevronBtn {
                    direction: "up"
                    visible: zoneStepper.acOn
                    enabled: zoneStepper.active
                    onTapped: zoneStepper.stepUp()
                }
            }
        }

        SequentialAnimation {
            id: zoneValueBump
            NumberAnimation { target: zoneValueText; property: "scale"; to: 1.14; duration: 80;  easing.type: Easing.OutQuad }
            NumberAnimation { target: zoneValueText; property: "scale"; to: 1.0;  duration: 140; easing.type: Easing.OutBack }
        }
    }

    Timer {
        interval: 1000
        running: BtController.playbackStatus === "playing"
        repeat: true
        onTriggered: BtController.updatePosition(1000)
    }

    // Auto day/night -- while enabled, the clock drives the theme every minute.
    // A manual toggle (Settings > Display) only sticks while this is off.
    Timer {
        interval: 60000
        running: mainRoot.autoNightMode
        repeat: true
        triggeredOnStart: true
        onTriggered: mainRoot.isNightMode = mainRoot.computeNight()
    }

    Image {
        anchors.fill: parent
        source: isNightMode ? "qrc:/Assets/Background/Dark-mode-bg.png" : "qrc:/Assets/Background/Light-mode-bg.png"
        fillMode: Image.PreserveAspectCrop

        Rectangle {
            anchors.fill: parent
            color: isNightMode ? Qt.rgba(0.06, 0.04, 0.12, 0.25) : Qt.rgba(1.0, 1.0, 1.0, 0.35)
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: baseMargin
        // Reserve the top strip for the global status bar
        anchors.topMargin: baseMargin + statusBarHeight + statusBarGap
        spacing: 20

        SidebarMenu {
            id: sidebarMenu
            Layout.fillHeight: true
            Layout.preferredWidth: mainRoot.isSidebarIconOnly ? 72 : 180
            // Sit below the status bar; the centered menu balances in the space after it
            Layout.topMargin: 0
            Layout.bottomMargin: 0
            Layout.leftMargin: -baseMargin

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            onCurrentIndexChanged: {
                if (currentIndex === 2 && mediaSwiper.currentIndex === 1) {
                    if (storedBtVolume > 0) {
                        BtController.setVolume(storedBtVolume);
                    }
                }
            }
        }

        HomeCard {
            id: homeCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: sidebarMenu.currentIndex === 0
            // Keep the tiles clear of the full-width climate bar at the bottom
            bottomReserve: Math.max(0, homeClimateBar.height - 24 + baseMargin)
            currentMediaTabIndex: mediaSwiper.currentIndex
            onRequestTab: index => { sidebarMenu.currentIndex = index }
        }

        NavigationCard {
            id: navigationCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: sidebarMenu.currentIndex === 1
        }

        CardSwiper {
            id: mediaSwiper
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: sidebarMenu.currentIndex === 2
            cardTitles: ["Internet Radio", "Bluetooth Audio", "Local Media"]

            RadioCard {}
            BluetoothCard {}
            LocalMediaCard {}

            onCurrentIndexChanged: {
                // Pause all other sources when switching cards
                if (currentIndex !== 0 && RadioController.playbackStatus === "playing") {
                    RadioController.pause();
                }
                if (currentIndex !== 1) {
                    if (BtController.playbackStatus === "playing") {
                        BtController.pause();
                    }
                    if (BtController.volume > 0) {
                        storedBtVolume = BtController.volume;
                        BtController.setVolume(0);
                    }
                }
                if (currentIndex !== 2 && LocalMediaController.playbackStatus === "playing") {
                    LocalMediaController.pause();
                }

                // Restore Bluetooth volume when switching to it
                if (currentIndex === 1 && storedBtVolume > 0) {
                    BtController.setVolume(storedBtVolume);
                }
            }
        }

        CardSwiper {
            id: phoneSwiper
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: sidebarMenu.currentIndex === 3
            cardTitles: ["Dialer", "Contacts", "Recents"]

            DialerCard {}
            ContactsCard {}
            RecentsCard {}
        }

        WeatherCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: sidebarMenu.currentIndex === 4
        }

        ClimateCard {
            id: climateCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: sidebarMenu.currentIndex === 5
        }

        SettingsCard {
            id: settingsCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: sidebarMenu.currentIndex === 6
        }
    }

    // -- Home: Climate bar -- aligned with the card area, docked to the bottom --
    Rectangle {
        id: homeClimateBar
        visible: sidebarMenu.currentIndex === 0
        z: 6
        anchors.left: parent.left
        anchors.leftMargin: sidebarMenu.width + 20   // sidebar + RowLayout spacing
        anchors.right: parent.right
        anchors.rightMargin: baseMargin
        anchors.bottom: parent.bottom
        anchors.bottomMargin: baseMargin
        height: 90
        color: colorSurface
        border.color: colorStroke
        border.width: 1
        radius: radiusLarge

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 0
            anchors.bottomMargin: 0
            spacing: 0

            // ── Driver zone ──────────────────────────────────────────────
            HomeZoneStepper {
                iconSource: "qrc:/Assets/Home_climate/Stearing_Wheel.svg"
                label: "DRIVER"
                value: climateCard.driverTemperature
                acOn: climateCard.acOn
                active: climateCard.acOn && !climateCard.autoMode
                onStepDown: climateCard.driverTemperature = clamp(climateCard.driverTemperature - 1, climateCard.minTemp, climateCard.maxTemp)
                onStepUp:   climateCard.driverTemperature = clamp(climateCard.driverTemperature + 1, climateCard.minTemp, climateCard.maxTemp)
                Layout.alignment: Qt.AlignVCenter
            }

            // Divider
            Rectangle {
                width: 1; Layout.fillHeight: true
                Layout.topMargin: 16; Layout.bottomMargin: 16
                color: colorStroke
                Layout.leftMargin: 16; Layout.rightMargin: 16
            }

            // ── Fan speed (centre) ────────────────────────────────────────
            Item {
                id: fanCentreItem
                Layout.fillWidth: true
                Layout.fillHeight: true

                property real animatedFan: climateCard.fanSpeed
                Behavior on animatedFan { NumberAnimation { duration: 380; easing.type: Easing.InOutCubic } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    width: parent.width

                    // Icon + label
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6

                        Item {
                            implicitWidth: 16; implicitHeight: 16

                            Image {
                                id: fanWindIcon
                                anchors.fill: parent
                                source: "qrc:/Assets/Home_climate/wind.svg"
                                sourceSize: Qt.size(32, 32)
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                                visible: false
                            }
                            MultiEffect {
                                source: fanWindIcon
                                anchors.fill: fanWindIcon
                                colorization: 1.0
                                brightness: 0.6
                                colorizationColor: colorTextSubtle
                            }
                        }

                        Text {
                            text: climateCard.fanSpeed > 0
                                  ? "FAN · LEVEL " + climateCard.fanSpeed
                                  : "FAN · OFF"
                            color: colorTextSubtle
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.2
                        }
                    }

                    // Horizontal pill-segment bar
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        spacing: 5

                        Repeater {
                            model: climateCard.maxFanSpeed
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                height: 8
                                radius: 4

                                readonly property real fillA: (isNightMode ? 0.18 : 0.14)
                                                           + ((isNightMode ? 0.85 : 0.70) - (isNightMode ? 0.18 : 0.14))
                                                           * Math.max(0, Math.min(1, fanCentreItem.animatedFan - index))

                                color: fillA > 0.3
                                       ? Qt.rgba(colorAccent.r, colorAccent.g, colorAccent.b, fillA)
                                       : Qt.rgba(1, 1, 1, isNightMode ? 0.12 : 0.18)

                                Behavior on color { ColorAnimation { duration: 200 } }

                                scale: pillMa.pressed ? 0.90 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutBack } }

                                MouseArea {
                                    id: pillMa
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    onClicked: climateCard.fanSpeed = (climateCard.fanSpeed === index + 1) ? 0 : index + 1
                                }
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                width: 1; Layout.fillHeight: true
                Layout.topMargin: 16; Layout.bottomMargin: 16
                color: colorStroke
                Layout.leftMargin: 16; Layout.rightMargin: 16
            }

            // ── Passenger zone ────────────────────────────────────────────
            HomeZoneStepper {
                iconSource: "qrc:/Assets/Home_climate/person.svg"
                label: "PASSENGER"
                value: climateCard.passengerTemperature
                acOn: climateCard.acOn
                active: climateCard.acOn && !climateCard.autoMode
                coupled: !climateCard.dualZone
                onStepDown: {
                    if (climateCard.dualZone)
                        climateCard.passengerTemperature = clamp(climateCard.passengerTemperature - 1, climateCard.minTemp, climateCard.maxTemp)
                    else
                        climateCard.driverTemperature = clamp(climateCard.driverTemperature - 1, climateCard.minTemp, climateCard.maxTemp)
                }
                onStepUp: {
                    if (climateCard.dualZone)
                        climateCard.passengerTemperature = clamp(climateCard.passengerTemperature + 1, climateCard.minTemp, climateCard.maxTemp)
                    else
                        climateCard.driverTemperature = clamp(climateCard.driverTemperature + 1, climateCard.minTemp, climateCard.maxTemp)
                }
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // -- Status bar -- a real bar spanning most of the screen width (inset from
    // both edges, floating over the sidebar's empty top): page title on the left,
    // time / date / outside temp / connectivity on the right.
    Rectangle {
        id: statusBar
        z: 5
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: baseMargin
        anchors.leftMargin: baseMargin   // span most of the width, inset from both sides
        anchors.rightMargin: baseMargin
        height: statusBarHeight
        radius: radiusLarge
        color: colorSurface
        border.color: colorStroke
        border.width: 1

        property var now: effectiveDate()
        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: statusBar.now = effectiveDate()
        }

        // Page title (left)
        Text {
            id: pageTitle
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: ["Home", "Navigation", "Media", "Phone", "Weather", "Climate", "Settings"][sidebarMenu.currentIndex] || ""
            color: colorTextPrimary
            font.pixelSize: 16
            font.bold: true
        }

        // Door-open warning -- amber pill next to the title while any door is open.
        // Tap to re-show the door popup (which shows exactly which doors are open).
        Rectangle {
            id: doorWarn
            visible: VehicleController.anyDoorOpen
            anchors.left: pageTitle.right
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            height: 26
            width: doorWarnRow.implicitWidth + 20
            radius: 13
            color: Qt.rgba(1.0, 0.62, 0.26, warnMa.pressed ? 0.30 : 0.16)
            border.color: "#ff9f43"
            border.width: 1
            scale: warnMa.pressed ? 0.94 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }

            MouseArea {
                id: warnMa
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: doorStatusPopup.flash()
            }

            Row {
                id: doorWarnRow
                anchors.centerIn: parent
                spacing: 7

                Rectangle {
                    width: 8; height: 8; radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#ff9f43"
                    SequentialAnimation on opacity {
                        running: VehicleController.anyDoorOpen
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Door Open"
                    color: "#ff9f43"
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }

        // Time / date / temp / connectivity (right)
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatTime(statusBar.now, clockUse24Hour
                        ? (clockShowSeconds ? "HH:mm:ss" : "HH:mm")
                        : (clockShowSeconds ? "h:mm:ss AP" : "h:mm AP"))
                color: colorTextPrimary
                font.pixelSize: 15
                font.bold: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(statusBar.now, "ddd d MMM")
                color: colorTextSubtle
                font.pixelSize: 13
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: WeatherController.currentWeather.temperature !== undefined
                text: Math.round(WeatherController.currentWeather.temperature)
                      + (WeatherController.temperatureUnit === "fahrenheit" ? "°F" : "°C")
                color: colorTextSubtle
                font.pixelSize: 13
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1; height: 18
                color: colorStroke
            }

            // Connectivity labels -- accent when active, dimmed when not
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Text {
                    text: "GPS"
                    color: BtGpsController.active ? colorAccentAlt : colorTextSubtle
                    opacity: BtGpsController.active ? 1.0 : 0.4
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    text: "BT"
                    color: BtController.connected ? colorAccentAlt : colorTextSubtle
                    opacity: BtController.connected ? 1.0 : 0.4
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    visible: WifiController.available
                    text: "WiFi"
                    color: WifiController.connectedSsid !== "" ? colorAccentAlt : colorTextSubtle
                    opacity: WifiController.connectedSsid !== "" ? 1.0 : 0.4
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }
    }

    Item {
        id: callBanner
        z: 10
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: baseMargin
        width: 420
        height: 64
        opacity: PhoneController.callState === "idle" ? 0 : 1
        visible: opacity > 0

        property string callerDisplay: {
            if (PhoneController.callerName.length > 0) return PhoneController.callerName
            if (PhoneController.callerNumber.length > 0) return PhoneController.callerNumber
            return "Unknown caller"
        }

        property string callStatusText: {
            switch (PhoneController.callState) {
            case "incoming":
            case "waiting":
                return "Incoming call"
            case "dialing":
            case "alerting":
                return "Calling"
            case "active":
                return "In call"
            case "held":
                return "Call on hold"
            case "disconnected":
                return "Call ended"
            default:
                return "Call"
            }
        }

        property string callIconSource: {
            if (PhoneController.callState === "incoming" || PhoneController.callState === "waiting")
                return "qrc:/Assets/Phone/phone-call-inbound.svg"
            if (PhoneController.callState === "dialing" || PhoneController.callState === "alerting")
                return "qrc:/Assets/Phone/phone-call-outbound.svg"
            if (PhoneController.callState === "active")
                return "qrc:/Assets/Phone/phone-calling.svg"
            return "qrc:/Assets/Phone/phone.svg"
        }

        Behavior on opacity {
            NumberAnimation { duration: 160 }
        }

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: colorSurface
            border.color: colorStroke
            opacity: 0.98
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Item {
                width: 28
                height: 28

                Image {
                    id: callIcon
                    anchors.fill: parent
                    source: callBanner.callIconSource
                    sourceSize.width: 64
                    sourceSize.height: 64
                    mipmap: true
                    fillMode: Image.PreserveAspectFit
                    visible: false
                }

                MultiEffect {
                    source: callIcon
                    anchors.fill: parent
                    colorization: 1.0
                    brightness: 1.0
                    colorizationColor: colorAccent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: callBanner.callStatusText
                    color: colorTextMuted
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Text {
                    text: callBanner.callerDisplay
                    color: colorTextPrimary
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                spacing: 8
                Layout.alignment: Qt.AlignVCenter

                // Green Answer Button (Incoming call only)
                Button {
                    id: answerCallBtn
                    implicitWidth: 38
                    implicitHeight: 38
                    visible: PhoneController.callState === "incoming"
                    background: Rectangle {
                        radius: 19
                        color: answerCallBtn.down ? "#3cb34c" : "#4cd964"
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                    }
                    contentItem: Item {
                        Image {
                            id: answerIcon
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: "qrc:/Assets/Phone/phone.svg"
                            sourceSize.width: 36
                            sourceSize.height: 36
                            mipmap: true
                            fillMode: Image.PreserveAspectFit
                            visible: false
                        }
                        MultiEffect {
                            source: answerIcon
                            anchors.fill: answerIcon
                            colorization: 1.0
                            brightness: 1.0
                            colorizationColor: "#ffffff"
                        }
                    }
                    onClicked: {
                        PhoneController.answer();
                    }
                }

                // Red Hang Up / Decline Button
                Button {
                    id: hangupCallBtn
                    implicitWidth: 38
                    implicitHeight: 38
                    background: Rectangle {
                        radius: 19
                        color: hangupCallBtn.down ? "#cc2e25" : "#ff3b30"
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                    }
                    contentItem: Item {
                        Image {
                            id: hangupIcon
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: "qrc:/Assets/Phone/phone-call-end.svg"
                            sourceSize.width: 36
                            sourceSize.height: 36
                            mipmap: true
                            fillMode: Image.PreserveAspectFit
                            visible: false
                        }
                        MultiEffect {
                            source: hangupIcon
                            anchors.fill: hangupIcon
                            colorization: 1.0
                            brightness: 1.0
                            colorizationColor: "#ffffff"
                        }
                    }
                    onClicked: {
                        PhoneController.hangup();
                    }
                }
            }
        }
    }

    Connections {
        target: RadioController
        function onPlaybackStatusChanged() {
            // If radio starts playing but it isn't the selected media source, pause it
            if (!isRadioActive && RadioController.playbackStatus === "playing") {
                RadioController.pause();
            }
        }
    }

    Connections {
        target: BtController
        function onPlaybackStatusChanged() {
            // If bluetooth starts playing (e.g. from phone) but it isn't the selected media source, pause it
            if (!isBluetoothActive && BtController.playbackStatus === "playing") {
                BtController.pause();
                if (BtController.volume > 0) {
                    storedBtVolume = BtController.volume;
                    BtController.setVolume(0);
                }
            }
        }
        function onVolumeChanged() {
            // If the phone changes the volume while bluetooth isn't the selected media source, remember it but force mute
            if (!isBluetoothActive && BtController.volume > 0) {
                storedBtVolume = BtController.volume;
                BtController.setVolume(0);
            } else if (isBluetoothActive && BtController.volume > 0) {
                // Just keep our stored volume up to date when active
                storedBtVolume = BtController.volume;
            }
        }
    }

    // -- Bluetooth pairing confirmation overlay (numeric comparison) --
    Rectangle {
        id: pairingOverlay
        anchors.fill: parent
        z: 200
        color: Qt.rgba(0, 0, 0, 0.55)
        visible: false
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        property string deviceName: ""
        property string passkey: ""

        function close() { pairingOverlay.visible = false }

        Connections {
            target: BtController
            function onPairingRequested(deviceName, passkey) {
                pairingOverlay.deviceName = deviceName
                pairingOverlay.passkey = passkey
                pairingOverlay.visible = true
            }
            function onPairingCancelled() { pairingOverlay.close() }
        }

        // Swallow clicks so nothing behind the modal reacts
        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.centerIn: parent
            width: 400
            height: 280
            radius: mainRoot.radiusLarge
            color: mainRoot.colorSurface
            border.color: mainRoot.colorStroke
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 12

                Text {
                    text: "Bluetooth Pairing Request"
                    color: mainRoot.colorTextPrimary
                    font.pixelSize: 18
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "“" + pairingOverlay.deviceName + "” wants to pair."
                    color: mainRoot.colorTextSubtle
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Text {
                    text: "Confirm this code matches the one shown on your phone:"
                    color: mainRoot.colorTextSubtle
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                }

                Text {
                    text: pairingOverlay.passkey
                    color: mainRoot.colorAccent
                    font.pixelSize: 40
                    font.bold: true
                    font.letterSpacing: 6
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillHeight: true
                    verticalAlignment: Text.AlignVCenter
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Cancel
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: 14
                        color: cancelMa.pressed ? mainRoot.colorSurfaceAlt : "transparent"
                        border.color: mainRoot.colorStroke
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: mainRoot.colorTextPrimary
                            font.pixelSize: 15
                            font.bold: true
                        }
                        MouseArea {
                            id: cancelMa
                            anchors.fill: parent
                            onClicked: { BtController.confirmPairing(false); pairingOverlay.close() }
                        }
                    }

                    // Pair
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: 14
                        color: pairMa.pressed
                            ? Qt.darker(mainRoot.colorAccent, 1.15)
                            : mainRoot.colorAccent
                        Text {
                            anchors.centerIn: parent
                            text: "Pair"
                            color: mainRoot.isNightMode ? "#1a1824" : "#ffffff"
                            font.pixelSize: 15
                            font.bold: true
                        }
                        MouseArea {
                            id: pairMa
                            anchors.fill: parent
                            onClicked: { BtController.confirmPairing(true); pairingOverlay.close() }
                        }
                    }
                }
            }
        }
    }

    // -- Door status popup -----------------------------------------------------
    // Fills the whole area under the status bar (same insets as the cards),
    // above all other layers (z:20). Flashes on door-open, auto-releases after
    // ~2.5 s. Persistent warning lives in the status bar (left).
    DoorStatusPopup {
        id: doorStatusPopup
        z: 20
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: baseMargin
        anchors.rightMargin: baseMargin
        anchors.topMargin: baseMargin + statusBarHeight + statusBarGap
        anchors.bottomMargin: baseMargin

        // Forward the app-wide colour tokens
        colorSurface:     mainRoot.colorSurface
        colorStroke:      mainRoot.colorStroke
        colorTextPrimary: mainRoot.colorTextPrimary
        colorTextSubtle:  mainRoot.colorTextSubtle
        colorAccent:      mainRoot.colorAccent
    }

    // -- Door manual control panel (shown when UART is unavailable) -----------
    // Slim vertical strip on the right edge -- does not overlap main content.
    Rectangle {
        id: doorManualPanel
        visible: !VehicleController.uartAvailable
        z: 15
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 48
        height: column.implicitHeight + 20
        radius: radiusSmall
        color: colorSurface
        border.color: colorStroke
        border.width: 1

        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Column {
            id: column
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Warning indicator
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "!"
                font.pixelSize: 11
                color: colorAccent
            }

            Repeater {
                model: [
                    { label: "FL", open: VehicleController.doorFL },
                    { label: "FR", open: VehicleController.doorFR },
                    { label: "RL", open: VehicleController.doorRL },
                    { label: "RR", open: VehicleController.doorRR }
                ]

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: 36; height: 28; radius: 6
                    color: modelData.open ? colorAccent : colorSurfaceInset
                    border.color: colorStroke; border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: modelData.open ? (isNightMode ? "#1a1824" : "#ffffff") : colorTextPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (index === 0) VehicleController.setDoorFL(!modelData.open)
                            else if (index === 1) VehicleController.setDoorFR(!modelData.open)
                            else if (index === 2) VehicleController.setDoorRL(!modelData.open)
                            else VehicleController.setDoorRR(!modelData.open)
                        }
                    }
                }
            }
        }
    }
}
