import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Sylph.Weather 1.0

// Weather settings: location search + units.
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

    // A selectable unit chip
    component UnitChip: Rectangle {
        property string label: ""
        property bool active: false
        signal picked()
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: 10
        color: active ? Qt.rgba(colorAccent.r, colorAccent.g, colorAccent.b, 0.22) : "transparent"
        border.color: active ? Qt.rgba(colorAccent.r, colorAccent.g, colorAccent.b, 0.5) : colorStroke
        border.width: 1
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
            anchors.centerIn: parent
            text: parent.label
            color: parent.active ? colorTextPrimary : colorTextSubtle
            font.pixelSize: 13
            font.bold: parent.active
        }
        MouseArea { anchors.fill: parent; onClicked: parent.picked() }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        Text {
            text: "Weather"
            color: colorTextPrimary
            font.pixelSize: 20
            font.bold: true
        }

        // -- Current location --
        GlassPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            radiusSize: radiusSmall
            colorSurface: colorSurfaceInset
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: "Location"; color: colorTextSubtle; font.pixelSize: 12 }
                Text {
                    text: WeatherController.cityName
                    color: colorTextPrimary
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        // -- Search --
        TextField {
            id: searchField
            Layout.fillWidth: true
            font.pixelSize: 14
            color: colorTextPrimary
            placeholderText: "Search city…"
            placeholderTextColor: colorTextSubtle
            background: Rectangle {
                radius: 10
                color: colorSurfaceInset
                border.color: searchField.activeFocus ? colorAccent : colorStroke
                border.width: 1
            }
            onTextEdited: searchTimer.restart()
            Timer {
                id: searchTimer
                interval: 350
                onTriggered: WeatherController.searchCity(searchField.text)
            }
        }

        ListView {
            id: results
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: WeatherController.searchResults

            Text {
                anchors.centerIn: parent
                width: parent.width - 24
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: searchField.text.length === 0
                    ? "Search for a city to set your weather location."
                    : "No matches."
                color: colorTextSubtle
                font.pixelSize: 12
                visible: results.count === 0
            }

            delegate: Rectangle {
                required property var modelData
                width: results.width
                height: 56
                radius: radiusSmall
                color: rMa.pressed ? Qt.rgba(colorAccent.r, colorAccent.g, colorAccent.b, 0.15) : colorSurfaceInset
                border.color: colorStroke
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                    Text { text: "CITY"; font.pixelSize: 18 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: modelData.name
                            color: colorTextPrimary
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: [modelData.admin1, modelData.country].filter(function(s){ return s && s.length }).join(", ")
                            color: colorTextSubtle
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                MouseArea {
                    id: rMa
                    anchors.fill: parent
                    onClicked: {
                        WeatherController.setLocation(modelData.latitude, modelData.longitude, modelData.name)
                        WeatherController.clearSearchResults()
                        searchField.text = ""
                        searchField.focus = false
                    }
                }
            }
        }

        // -- Units --
        Text { text: "Temperature"; color: colorTextSubtle; font.pixelSize: 12; font.bold: true }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            UnitChip {
                label: "Celsius (°C)"
                active: WeatherController.temperatureUnit === "celsius"
                onPicked: WeatherController.temperatureUnit = "celsius"
            }
            UnitChip {
                label: "Fahrenheit (°F)"
                active: WeatherController.temperatureUnit === "fahrenheit"
                onPicked: WeatherController.temperatureUnit = "fahrenheit"
            }
        }

        Text { text: "Wind speed"; color: colorTextSubtle; font.pixelSize: 12; font.bold: true }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            UnitChip {
                label: "km/h"
                active: WeatherController.windSpeedUnit === "kmh"
                onPicked: WeatherController.windSpeedUnit = "kmh"
            }
            UnitChip {
                label: "mph"
                active: WeatherController.windSpeedUnit === "mph"
                onPicked: WeatherController.windSpeedUnit = "mph"
            }
            UnitChip {
                label: "m/s"
                active: WeatherController.windSpeedUnit === "ms"
                onPicked: WeatherController.windSpeedUnit = "ms"
            }
        }
    }
}
