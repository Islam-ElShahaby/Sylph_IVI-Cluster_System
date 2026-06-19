import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Sylph.Weather 1.0

// Landscape weather screen (replaces the old "Vehicle" tab). Data comes from
// the shared WeatherController singleton (Open-Meteo). Location + units are
// configured in Settings -> Weather.
Item {
    id: root

    // Theme tokens
    property int radiusLarge: typeof mainRoot !== "undefined" ? mainRoot.radiusLarge : 28
    property int radiusSmall: typeof mainRoot !== "undefined" ? mainRoot.radiusSmall : 16
    property color colorSurface: typeof mainRoot !== "undefined" ? mainRoot.colorSurface : "#c80e0a17"
    property color colorSurfaceInset: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceInset : Qt.rgba(0.17, 0.15, 0.22, 0.5)
    property color colorStroke: typeof mainRoot !== "undefined" ? mainRoot.colorStroke : "#2bffffff"
    property color colorTextPrimary: typeof mainRoot !== "undefined" ? mainRoot.colorTextPrimary : "#ffffff"
    property color colorTextSubtle: typeof mainRoot !== "undefined" ? mainRoot.colorTextSubtle : "#b8b2c8"
    property color colorAccent: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"
    property color colorAccentAlt: typeof mainRoot !== "undefined" ? mainRoot.colorAccentAlt : "#7de2ff"

    readonly property var cw: WeatherController.currentWeather
    readonly property string tempSym: WeatherController.temperatureUnit === "fahrenheit" ? "°F" : "°C"
    readonly property string windSym: ({ "kmh": "km/h", "mph": "mph", "ms": "m/s", "kn": "kn" })[WeatherController.windSpeedUnit] || "km/h"

    function rt(v) { return (v === undefined || v === null) ? "--" : Math.round(v) }

    // Map a WMO weather code to one of the bundled PNG icons.
    function iconSource(code, day) {
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
    function weatherText(code) {
        if (code === undefined || code === null) return ""
        if (code <= 1)  return "Clear"
        if (code <= 3)  return "Partly cloudy"
        if (code <= 48) return "Fog"
        if (code <= 57) return "Drizzle"
        if (code <= 67) return "Rain"
        if (code <= 77) return "Snow"
        if (code <= 82) return "Rain showers"
        if (code <= 86) return "Snow showers"
        return "Thunderstorm"
    }
    function fmtHour(iso) {
        if (!iso) return "--"
        var d = new Date(iso); var h = d.getHours()
        if (h === 0) return "12 AM"; if (h < 12) return h + " AM"
        if (h === 12) return "12 PM"; return (h - 12) + " PM"
    }
    function fmtDay(dateStr) {
        if (!dateStr) return ""
        var d = new Date(dateStr + "T00:00:00")
        return ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][d.getDay()]
    }
    function isToday(dateStr) {
        if (!dateStr) return false
        var t = new Date(); var d = new Date(dateStr + "T00:00:00")
        return t.toDateString() === d.toDateString()
    }
    function todayOrLater(dateStr) {
        if (!dateStr) return false
        var d = new Date(dateStr + "T00:00:00")
        var t = new Date(); t.setHours(0, 0, 0, 0)
        return d >= t
    }

    // -- Glass card background --
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
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.4
        shadowBlur: 20
        shadowVerticalOffset: 10
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 20

        // ============================================
        //  MAIN FOCUS -- today + hourly
        // ============================================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8


            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: WeatherController.cityName
                    color: colorTextPrimary
                    font.pixelSize: 26
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: WeatherController.loading ? "..." : "Refresh"
                    color: colorTextSubtle
                    font.pixelSize: 20
                    MouseArea { anchors.fill: parent; onClicked: WeatherController.refresh() }
                }
            }

            Text {
                text: weatherText(cw.weatherCode)
                color: colorTextSubtle
                font.pixelSize: 15
            }

            // Big current temperature
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Image {
                    source: root.iconSource(cw.weatherCode, cw.isDay === undefined ? true : cw.isDay)
                    sourceSize: Qt.size(120, 120)
                    Layout.preferredWidth: 84
                    Layout.preferredHeight: 84
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }
                Text {
                    text: rt(cw.temperature) + root.tempSym
                    color: colorTextPrimary
                    font.pixelSize: 60
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
            }

            

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                Text {
                    text: "Feels like " + rt(cw.apparentTemperature) + root.tempSym
                    color: colorTextSubtle
                    font.pixelSize: 14
                }
                Text {
                    text: "H: " + rt(cw.tempMax) + "°   L: " + rt(cw.tempMin) + "°"
                    color: colorTextSubtle
                    font.pixelSize: 14
                }
                Item { Layout.fillWidth: true }
            }

            // Flexible gap -- absorbs the slack so stats + hourly sit lower
            Item { Layout.fillHeight: true }

            // Quick stats -- one compact row
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 10

                component Stat: Rectangle {
                    property string label: ""
                    property string value: ""
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    radius: radiusSmall
                    color: colorSurfaceInset
                    border.color: colorStroke
                    border.width: 1
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 1
                        Text { text: label; color: colorTextSubtle; font.pixelSize: 11 }
                        Text { text: value; color: colorTextPrimary; font.pixelSize: 17; font.bold: true }
                    }
                }

                Stat { label: "Humidity"; value: root.rt(cw.humidity) + "%" }
                Stat { label: "Wind"; value: root.rt(cw.windSpeed) + " " + root.windSym }
                Stat { label: "UV index"; value: root.rt(cw.uvIndex) }
                Stat { label: "Precip"; value: root.rt(cw.precipProbability) + "%" }
            }

            // Hourly forecast scroller
            Text { text: "Hourly"; color: colorTextSubtle; font.pixelSize: 12; font.bold: true; Layout.topMargin: 6 }

            ListView {
                id: hourly
                Layout.fillWidth: true
                // Just tall enough for one card's contents (no vertical stretch)
                Layout.preferredHeight: 150
                orientation: ListView.Horizontal
                spacing: 10
                clip: true
                model: WeatherController.hourlyModel

                delegate: Rectangle {
                    required property var modelData
                    width: 84
                    height: hourly.height
                    radius: radiusSmall
                    color: colorSurfaceInset
                    border.color: colorStroke
                    border.width: 1
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16   // larger inner padding
                        spacing: 6
                        Text {
                            text: root.fmtHour(modelData.time)
                            color: colorTextSubtle
                            font.pixelSize: 12
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Image {
                            source: root.iconSource(modelData.weatherCode, modelData.isDay)
                            sourceSize: Qt.size(80, 80)
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44
                            Layout.alignment: Qt.AlignHCenter
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                        }
                        Text {
                            text: root.rt(modelData.temperature) + "°"
                            color: colorTextPrimary
                            font.pixelSize: 17
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "Rain " + root.rt(modelData.precipProbability) + "%"
                            color: colorAccentAlt
                            font.pixelSize: 11
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }

        // Divider
        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: colorStroke; opacity: 0.6 }

        // ============================================
        //  7-DAY FORECAST
        // ============================================
        ColumnLayout {
            // Pin the width (a ColumnLayout defaults fillWidth=true, which let it
            // get squeezed and clip the high-temp column). 270 fits the row's
            // fixed columns (day+icon+precip+low+high ≈ 266px) without overflow.
            Layout.fillWidth: false
            Layout.preferredWidth: 270
            Layout.fillHeight: true
            spacing: 10

            Text { text: "7-day forecast"; color: colorTextSubtle; font.pixelSize: 12; font.bold: true }
            ColumnLayout {
                id: daily
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                Repeater {
                    model: WeatherController.dailyModel

                    delegate: Rectangle {
                        required property var modelData

                        visible: root.todayOrLater(modelData.date)
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: radiusSmall
                        color: root.isToday(modelData.date) ? Qt.rgba(colorAccent.r, colorAccent.g, colorAccent.b, 0.15) : colorSurfaceInset
                        border.color: root.isToday(modelData.date) ? colorAccent : colorStroke
                        border.width: 1

                        RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 6

                        Text {
                            text: root.isToday(modelData.date) ? "Today" : root.fmtDay(modelData.date)
                            color: colorTextPrimary
                            font.pixelSize: 14
                            font.bold: true
                            Layout.preferredWidth: 46
                        }
                        Image {
                            source: root.iconSource(modelData.weatherCode, true)
                            sourceSize: Qt.size(56, 56)
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Rain " + root.rt(modelData.precipProbability) + "%"
                            color: colorAccentAlt
                            font.pixelSize: 12
                            Layout.preferredWidth: 70
                            horizontalAlignment: Text.AlignRight
                        }
                        Text {
                            text: root.rt(modelData.tempMin) + "°"
                            color: colorTextSubtle
                            font.pixelSize: 15
                            Layout.preferredWidth: 30
                            horizontalAlignment: Text.AlignRight
                        }
                        Text {
                            text: root.rt(modelData.tempMax) + "°"
                            color: colorTextPrimary
                            font.pixelSize: 15
                            font.bold: true
                            Layout.preferredWidth: 36
                            horizontalAlignment: Text.AlignRight
                        }
                        }
                    }
                }
            }
        }
    }

    // Error banner
    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8
        text: WeatherController.errorString
        color: "#ff8e8e"
        font.pixelSize: 12
        visible: WeatherController.errorString !== ""
    }
}
