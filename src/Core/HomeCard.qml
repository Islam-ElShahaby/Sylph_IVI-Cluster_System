import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import MapLibre 3.0
import Sylph.Weather 1.0
import Sylph.Bluetooth 1.0
import Sylph.Radio 1.0
import Sylph.LocalMedia 1.0
import Sylph.Core 1.0

// Home dashboard: four shortcut tiles. Tapping a tile switches to that tab via
// the requestTab() signal (wired in Main.qml). Navigation fills the left,
// Media (top-right) and Weather (bottom-right) stack on the right, and a
// full-width Climate strip sits across the bottom.
Item {
    id: root

    // Tab indices to switch to (match the sidebar order)
    signal requestTab(int index)

    property int currentMediaTabIndex: 1 // default to Bluetooth
    property string activeMediaSource: {
        if (currentMediaTabIndex === 0) return "radio"
        if (currentMediaTabIndex === 2) return "local"
        return "bluetooth"
    }

    // True when the active source is playing -- drives the media tile's accent.
    readonly property bool mediaPlaying: {
        if (activeMediaSource === "radio") return RadioController.playbackStatus === "playing"
        if (activeMediaSource === "local") return LocalMediaController.playbackStatus === "playing"
        return BtController.playbackStatus === "playing"
    }

    // Bottom space reserved for the full-width climate bar (lives in Main.qml,
    // anchored to the window edge so it spans under the sidebar too).
    property int bottomReserve: 0

    property int radiusLarge: typeof mainRoot !== "undefined" ? mainRoot.radiusLarge : 28
    property int radiusSmall: typeof mainRoot !== "undefined" ? mainRoot.radiusSmall : 16
    property color colorSurface: typeof mainRoot !== "undefined" ? mainRoot.colorSurface : "#c80e0a17"
    property color colorSurfaceInset: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceInset : Qt.rgba(0.17, 0.15, 0.22, 0.5)
    property color colorStroke: typeof mainRoot !== "undefined" ? mainRoot.colorStroke : "#2bffffff"
    property color colorTextPrimary: typeof mainRoot !== "undefined" ? mainRoot.colorTextPrimary : "#ffffff"
    property color colorTextSubtle: typeof mainRoot !== "undefined" ? mainRoot.colorTextSubtle : "#b8b2c8"
    property color colorAccent: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"
    property color colorAccentAlt: typeof mainRoot !== "undefined" ? mainRoot.colorAccentAlt : "#7de2ff"
    property color colorSurfaceAlt: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceAlt : "#dd141021"

    property bool isNightMode: typeof mainRoot !== "undefined" ? mainRoot.isNightMode : true

    readonly property var cw: WeatherController.currentWeather
    readonly property string tempSym: WeatherController.temperatureUnit === "fahrenheit" ? "°F" : "°C"
    readonly property var today: WeatherController.dailyModel.length > 0 ? WeatherController.dailyModel[0] : null

    function rt(v) { return (v === undefined || v === null) ? "--" : Math.round(v) }

    // Short condition label + a translucent tint per weather code, so the weather
    // tile picks up a mood instead of sitting flat like everything around it.
    function wWord(code, day) {
        if (code === undefined || code === null) return ""
        if (code <= 1)  return day ? "Sunny" : "Clear"
        if (code === 2) return "Partly Cloudy"
        if (code <= 3)  return "Cloudy"
        if (code <= 48) return "Fog"
        if (code <= 67) return "Rain"
        if (code <= 77) return "Snow"
        if (code <= 82) return "Showers"
        if (code <= 86) return "Snow"
        return "Storm"
    }
    function wTint(code, day) {
        if (!day)        return Qt.rgba(0.10, 0.09, 0.22, 0.55)  // night indigo
        if (code === undefined || code === null) return Qt.rgba(0.45, 0.32, 0.10, 0.40)
        if (code <= 1)   return Qt.rgba(0.45, 0.32, 0.10, 0.40)  // sun amber
        if (code <= 48)  return Qt.rgba(0.20, 0.22, 0.28, 0.45)  // cloud/fog grey
        return Qt.rgba(0.12, 0.20, 0.38, 0.50)                   // rain/snow blue
    }
    function wIcon(code, day) {
        var b = "qrc:/Assets/Weather_icons/"
        if (code === undefined || code === null) return b + (day ? "sunny.png" : "night.png")
        if (code <= 1)  return b + (day ? "sunny.png" : "night.png")
        if (code === 2) return b + "partly-cloudy.png"
        if (code <= 3)  return b + "cloudy.png"
        if (code <= 48) return b + "fog.png"
        if (code <= 64) return b + "rain.png"
        if (code === 65) return b + "heavy-rain.png"
        if (code <= 67) return b + "hail-rain.png"
        if (code <= 74) return b + "snow.png"
        if (code <= 77) return b + "heavy-snow.png"
        if (code <= 81) return b + "rain.png"
        if (code === 82) return b + "heavy-rain.png"
        if (code <= 86) return b + "snow.png"
        return b + "thunder-storm.png"
    }

    // Reusable glass tile with a tap action; children go into the padded body.
    component Tile: Rectangle {
        id: tile
        default property alias content: body.data
        property color tintColor: "transparent"
        Behavior on tintColor { ColorAnimation { duration: 400 } }
        signal activated()
        radius: root.radiusLarge
        color: root.colorSurface
        border.color: tileMa.pressed ? root.colorAccent : root.colorStroke
        border.width: 1
        scale: tileMa.pressed ? 0.985 : 1.0
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 100 } }

        // Condition mood: tint fades from the icon side to clear, clipped to the card.
        Rectangle {
            anchors.fill: parent
            radius: tile.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: tile.tintColor }
                GradientStop { position: 1.0; color: Qt.rgba(tile.tintColor.r, tile.tintColor.g, tile.tintColor.b, 0) }
            }
        }

        Item { id: body; anchors.fill: parent; anchors.margins: 18 }

        // Open chevron
        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 16
            text: "›"
            color: root.colorTextSubtle
            font.pixelSize: 20
        }

        MouseArea { id: tileMa; anchors.fill: parent; onClicked: tile.activated() }
    }

    // -- Mini map style -- switches between CARTO dark/light based on theme --
    property string miniNavMapStyle: {
        var variant = isNightMode ? "dark_all" : "light_all"
        return "data:application/json;charset=utf-8," + encodeURIComponent(JSON.stringify({
            "version": 8,
            "sources": {
                "carto-tiles": {
                    "type": "raster",
                    "tiles": [
                        "https://a.basemaps.cartocdn.com/" + variant + "/{z}/{x}/{y}@2x.png",
                        "https://b.basemaps.cartocdn.com/" + variant + "/{z}/{x}/{y}@2x.png",
                        "https://c.basemaps.cartocdn.com/" + variant + "/{z}/{x}/{y}@2x.png"
                    ],
                    "tileSize": 256,
                    "attribution": "© OpenStreetMap © CARTO"
                }
            },
            "layers": [{"id": "carto-layer", "type": "raster", "source": "carto-tiles"}]
        }))
    }

    onIsNightModeChanged: {
        if (miniMapLoader.item) {
            var lat = BtGpsController.active ? BtGpsController.latitude  : 30.0383
            var lng = BtGpsController.active ? BtGpsController.longitude : 31.2102
            var hdg = (BtGpsController.active && BtGpsController.heading >= 0) ? BtGpsController.heading : 0
            Qt.callLater(function() {
                miniMapLoader.item.easeTo({"center": [lat, lng], "zoom": 14.5, "bearing": hdg, "pitch": 40.0}, {"duration": 0})
            })
        }
    }

    Component {
        id: miniMapComponent
        MapLibre {
            style: root.miniNavMapStyle
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.bottomMargin: root.bottomReserve + 16
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // -- Navigation (left) -- Mini Live Map --
            Item {
                id: miniNavTile
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Fallback card shown while map tiles load
                Rectangle {
                    anchors.fill: parent
                    radius: root.radiusLarge
                    color: root.colorSurface
                    border.color: root.colorStroke
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "MAP"
                        font.pixelSize: 60
                        opacity: 0.2
                    }
                }

                // Map + rounded clip via OpacityMask
                Item {
                    anchors.fill: parent

                    Loader {
                        id: miniMapLoader
                        anchors.fill: parent
                        active: true     // must stay alive -- OpacityMask holds a source reference;
                                         // destroying the item while the mask still points to it causes a SIGSEGV
                        sourceComponent: miniMapComponent
                        visible: false   // rendered through the OpacityMask below

                        onLoaded: {
                            var lat = BtGpsController.active ? BtGpsController.latitude  : 30.0383
                            var lng = BtGpsController.active ? BtGpsController.longitude : 31.2102
                            var hdg = (BtGpsController.active && BtGpsController.heading >= 0) ? BtGpsController.heading : 0
                            item.easeTo({"center": [lat, lng], "zoom": 14.5, "bearing": hdg, "pitch": 40.0}, {"duration": 0})
                        }
                    }

                    Rectangle {
                        id: miniMapMask
                        anchors.fill: parent
                        radius: root.radiusLarge
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: parent
                        source: miniMapLoader
                        maskSource: miniMapMask
                    }
                }

                // Bottom gradient overlay with GPS status
                Rectangle {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    anchors.bottom: parent.bottom
                    height: 68
                    radius: root.radiusLarge
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0.04, 0.03, 0.08, 0.90) }
                    }

                    Row {
                        anchors.left:    parent.left
                        anchors.bottom:  parent.bottom
                        anchors.margins: 14
                        spacing: 8

                        // Pulsing GPS dot
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: BtGpsController.active ? root.colorAccentAlt : root.colorTextSubtle

                            SequentialAnimation on opacity {
                                running: BtGpsController.active
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.2; duration: 900; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: BtGpsController.active
                                ? (Math.round(BtGpsController.speed * 3.6) + " km/h  ·  " + BtGpsController.satellites + " sats")
                                : "No GPS Signal"
                            color: root.colorTextPrimary
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }
                }

                // Static border drawn on top of the map
                Rectangle {
                    anchors.fill: parent
                    radius: root.radiusLarge
                    color: "transparent"
                    border.color: mapMa.pressed ? root.colorAccent : root.colorStroke
                    border.width: 1
                    z: 3
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                // Open chevron + tap to open full Navigation
                Text {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 16
                    text: "›"
                    color: root.colorTextSubtle
                    font.pixelSize: 20
                    z: 4
                }

                MouseArea {
                    id: mapMa
                    anchors.fill: parent
                    z: 4
                    onClicked: root.requestTab(1)
                }


                // Update map camera when GPS position changes
                Connections {
                    target: BtGpsController
                    function onPositionChanged() {
                        if (miniMapLoader.item && BtGpsController.active) {
                            miniMapLoader.item.easeTo({
                                "center":  [BtGpsController.latitude, BtGpsController.longitude],
                                "zoom":    14.5,
                                "bearing": BtGpsController.heading >= 0 ? BtGpsController.heading : 0,
                                "pitch":   40.0
                            }, {"duration": 1000})
                        }
                    }
                }
            }

            // -- Right column: Media (top) + Weather (bottom) --
            ColumnLayout {
                Layout.fillWidth: false
                Layout.preferredWidth: 360
                Layout.fillHeight: true
                spacing: 16

                // Media
                // Media
                Item {
                    id: mediaTile
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Background & Border -- accented while playing
                    Rectangle {
                        anchors.fill: parent
                        radius: root.radiusLarge
                        color: root.colorSurface
                        border.color: root.mediaPlaying ? root.colorAccent : root.colorStroke
                        border.width: root.mediaPlaying ? 2 : 1
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                    }

                    // Cover Art Background (Only for Bluetooth / when available)
                    Item {
                        anchors.fill: parent
                        visible: root.activeMediaSource === "bluetooth" && BtController.coverArt !== "" && BtController.coverArt !== "qrc:/cover_placeholder.png"
                        
                        Image {
                            id: coverBg
                            anchors.fill: parent
                            source: BtController.coverArt
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                        }
                        
                        Rectangle {
                            id: coverMask
                            anchors.fill: parent
                            radius: root.radiusLarge
                            visible: false
                        }
                        
                        OpacityMask {
                            anchors.fill: parent
                            source: coverBg
                            maskSource: coverMask
                        }
                        
                        // Glassmorphic dark overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: root.radiusLarge
                            color: Qt.rgba(0.08, 0.07, 0.13, 0.70) // Dark overlay for readability
                        }
                    }



                    // Content
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 8

                        // Header (Icon + Title)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Text { 
                                text: root.activeMediaSource === "radio" ? "Radio" :
                                      root.activeMediaSource === "local" ? "Local Media" : "Bluetooth"
                                color: root.colorTextPrimary; font.pixelSize: 16; font.bold: true 
                            }
                            Item { Layout.fillWidth: true }
                        }

                        // Track Info
                        Text {
                            text: {
                                if (root.activeMediaSource === "radio") return RadioController.nowPlaying || RadioController.stationName || "No Station"
                                if (root.activeMediaSource === "local") return LocalMediaController.currentTitle || "No Track"
                                return BtController.trackTitle || "No Track"
                            }
                            color: root.colorTextPrimary
                            font.pixelSize: 20
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: {
                                if (root.activeMediaSource === "radio") return "FM/AM"
                                if (root.activeMediaSource === "local") return LocalMediaController.currentArtist || "Unknown Artist"
                                return BtController.artist || "Unknown Artist"
                            }
                            color: root.colorTextSubtle
                            font.pixelSize: 14
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        
                        Item { Layout.fillHeight: true }

                        // Controls Area
                        Item {
                            id: controlsMa
                            Layout.fillWidth: true
                            implicitHeight: controlsRow.implicitHeight

                            RowLayout {
                                id: controlsRow
                                anchors.fill: parent
                                spacing: 8
                                
                                // Shuffle (Local only)
                                MediaButton {
                                    visible: root.activeMediaSource === "local"
                                    iconSource: "qrc:/Assets/Media/shuffle-svgrepo-com.svg"
                                    size: 40
                                    iconSize: 18
                                    fillColor: LocalMediaController.shuffle ? root.colorAccent : root.colorSurfaceAlt
                                    textColor: LocalMediaController.shuffle ? "#c80e0a17" : root.colorTextPrimary
                                    onClicked: LocalMediaController.setShuffle(!LocalMediaController.shuffle)
                                }

                                // Prev (Bluetooth & Local)
                                MediaButton {
                                    visible: root.activeMediaSource !== "radio"
                                    iconSource: "qrc:/Assets/Media/skip-previous-svgrepo-com.svg"
                                    size: 40
                                    iconSize: 18
                                    onClicked: {
                                        if (root.activeMediaSource === "local") LocalMediaController.previous()
                                        else BtController.previous()
                                    }
                                }

                                // Play/Pause
                                MediaButton {
                                    property bool isPlaying: root.mediaPlaying
                                    iconSource: isPlaying ? "qrc:/Assets/Media/pause-svgrepo-com.svg" : "qrc:/Assets/Media/play-svgrepo-com.svg"
                                    size: 48
                                    iconSize: 22
                                    fillColor: root.colorSurfaceAlt
                                    onClicked: {
                                        if (root.activeMediaSource === "radio") isPlaying ? RadioController.pause() : RadioController.play()
                                        else if (root.activeMediaSource === "local") isPlaying ? LocalMediaController.pause() : LocalMediaController.play()
                                        else isPlaying ? BtController.pause() : BtController.play()
                                    }
                                }

                                // Next (Bluetooth & Local)
                                MediaButton {
                                    visible: root.activeMediaSource !== "radio"
                                    iconSource: "qrc:/Assets/Media/skip-next-svgrepo-com.svg"
                                    size: 40
                                    iconSize: 18
                                    onClicked: {
                                        if (root.activeMediaSource === "local") LocalMediaController.next()
                                        else BtController.next()
                                    }
                                }
                                
                                Item { Layout.fillWidth: true; Layout.minimumWidth: 10 }
                                
                                Text { text: "VOL"; color: root.colorTextSubtle; font.pixelSize: 14 }
                                
                                // Volume Slider
                                Slider {
                                    id: tileVolSlider
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 60
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitHeight: 24   // without this the custom handle/bg give the slider ~0 clickable height
                                    from: 0
                                    to: 100
                                    stepSize: 1
                                    
                                    Binding {
                                        target: tileVolSlider
                                        property: "value"
                                        value: {
                                            if (root.activeMediaSource === "radio") return RadioController.volume
                                            if (root.activeMediaSource === "local") return LocalMediaController.volume
                                            return BtController.volume
                                        }
                                        when: !tileVolSlider.pressed
                                    }
                                    
                                    onMoved: {
                                        if (root.activeMediaSource === "radio") RadioController.setVolume(Math.round(value))
                                        else if (root.activeMediaSource === "local") LocalMediaController.setVolume(Math.round(value))
                                        else BtController.setVolume(Math.round(value))
                                    }

                                    background: Rectangle {
                                        x: 0
                                        y: (parent.height - height) / 2
                                        width: parent.width
                                        height: 4
                                        radius: 2
                                        color: root.colorStroke

                                        Rectangle {
                                            width: parent.width * tileVolSlider.visualPosition
                                            height: parent.height
                                            radius: parent.radius
                                            color: root.colorAccentAlt
                                        }
                                    }
                                    handle: Rectangle {
                                        x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                        width: 12
                                        height: 12
                                        radius: 6
                                        color: root.colorSurface
                                        border.color: root.colorAccentAlt
                                        border.width: 2
                                    }
                                }
                            }
                        }

                        // Progress Bar (Bluetooth & Local)
                        Item {
                            visible: root.activeMediaSource !== "radio"
                            Layout.fillWidth: true
                            implicitHeight: 14
                            
                            readonly property real positionMs: root.activeMediaSource === "local" ? LocalMediaController.position : BtController.position
                            readonly property real durationMs: root.activeMediaSource === "local" ? LocalMediaController.duration : BtController.duration
                            readonly property real progress: durationMs > 0 ? positionMs / durationMs : 0

                            Rectangle {
                                id: progressBarBg
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4
                                radius: 2
                                color: root.colorStroke
                            }

                            Rectangle {
                                anchors.left: progressBarBg.left
                                anchors.verticalCenter: progressBarBg.verticalCenter
                                width: progressBarBg.width * parent.progress
                                height: progressBarBg.height
                                radius: progressBarBg.radius
                                color: root.colorAccent
                                Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                            }
                            
                            // Seek area for Local Media
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -10
                                enabled: root.activeMediaSource === "local"
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (parent.durationMs > 0) {
                                        let newPos = (mouse.x / parent.width) * parent.durationMs;
                                        LocalMediaController.updatePosition(newPos);
                                    }
                                }
                            }
                        }
                    }
                }

                // Weather -- fixed (smaller) height so the media tile above gets
                // the extra room its controls + progress bar need. ponytail: tune this if media still crowds.
                Tile {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 132
                    onActivated: root.requestTab(4)
                    tintColor: root.wTint(root.cw.weatherCode, root.cw.isDay === undefined ? true : root.cw.isDay)

                    RowLayout {
                        anchors.fill: parent
                        spacing: 12
                        Image {
                            source: root.wIcon(root.cw.weatherCode, root.cw.isDay === undefined ? true : root.cw.isDay)
                            sourceSize: Qt.size(96, 96)
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 64
                            fillMode: Image.PreserveAspectFit
                            mipmap: true

                            // Slow breathe -- the same quiet motion language as the GPS dot.
                            SequentialAnimation on scale {
                                running: true
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.06; duration: 2200; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0;  duration: 2200; easing.type: Easing.InOutSine }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: WeatherController.cityName
                                color: root.colorTextSubtle
                                font.pixelSize: 14
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: root.rt(root.cw.temperature) + root.tempSym
                                color: root.colorTextPrimary
                                font.pixelSize: 34
                                font.bold: true
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Text {
                                    text: root.wWord(root.cw.weatherCode, root.cw.isDay === undefined ? true : root.cw.isDay)
                                    color: root.colorTextPrimary
                                    font.pixelSize: 13
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    visible: root.today !== null
                                    text: root.today
                                        ? "H:" + root.rt(root.today.tempMax) + "°  L:" + root.rt(root.today.tempMin) + "°"
                                        : ""
                                    color: root.colorTextSubtle
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
