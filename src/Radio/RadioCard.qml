import QtQuick
import QtQml
import QtQuick.Controls
import QtQuick.Layouts
import Sylph.Radio 1.0

Item {
    id: radioCardContainer

    property int radiusLarge: typeof mainRoot !== "undefined" ? mainRoot.radiusLarge : 28
    property int radiusSmall: typeof mainRoot !== "undefined" ? mainRoot.radiusSmall : 16
    property color colorSurface: typeof mainRoot !== "undefined" ? mainRoot.colorSurface : "#c80e0a17"
    property color colorSurfaceAlt: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceAlt : "#dd141021"
    property color colorStroke: typeof mainRoot !== "undefined" ? mainRoot.colorStroke : "#2bffffff"
    property color colorTextPrimary: typeof mainRoot !== "undefined" ? mainRoot.colorTextPrimary : "#ffffff"
    property color colorTextMuted: typeof mainRoot !== "undefined" ? mainRoot.colorTextMuted : "#eae6f8"
    property color colorTextSubtle: typeof mainRoot !== "undefined" ? mainRoot.colorTextSubtle : "#b8b2c8"
    property color colorAccent: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"
    property color colorAccentAlt: typeof mainRoot !== "undefined" ? mainRoot.colorAccentAlt : "#7de2ff"
    
    property int tagIndex: 0
    property int languageIndex: 0

    function applyRadioFilters() {
        let t = (tagBox.items && tagBox.items.length > tagBox.currentIndex) ? tagBox.items[tagBox.currentIndex] : "Any";
        let l = (languageBox.items && languageBox.items.length > languageBox.currentIndex) ? languageBox.items[languageBox.currentIndex] : "English";

        t = (t === "Any") ? "" : t;

        RadioController.searchStationsAdvanced("", t, "", l)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text { text: "Tags"; color: colorTextMuted; font.pixelSize: 12; Layout.preferredWidth: 70 }

                CircularSelector {
                    id: tagBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    items: RadioController.tags.length > 0 ? RadioController.tags : ["Any"]
                    currentIndex: radioCardContainer.tagIndex
                    onCurrentIndexChanged: radioCardContainer.tagIndex = currentIndex
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 50
                }

                Text { text: "Language"; color: colorTextMuted; font.pixelSize: 12; Layout.preferredWidth: 70 }

                CircularSelector {
                    id: languageBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    items: RadioController.languages.length > 0 ? RadioController.languages : ["English"]
                    currentIndex: radioCardContainer.languageIndex
                    onCurrentIndexChanged: radioCardContainer.languageIndex = currentIndex
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: RadioController.stationName !== "" ? RadioController.stationName : "No station selected"
                    color: colorTextPrimary
                    font.pixelSize: 20
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: "Stations: " + stationList.count
                    color: colorTextSubtle
                    font.pixelSize: 12
                }
            }
            Text {
                text: RadioController.nowPlaying
                color: colorTextMuted
                font.pixelSize: 14
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: RadioController.lastError
                color: "#ff8e8e"
                font.pixelSize: 12
                visible: RadioController.lastError !== ""
                Layout.fillWidth: true
            }
        }

        ListView {
            id: stationList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: RadioController.stationsModel
            spacing: 10
            clip: true

            Text {
                anchors.centerIn: parent
                text: "No stations yet."
                color: colorTextSubtle
                font.pixelSize: 12
                visible: stationList.count === 0 && !RadioController.loading
            }

            // Smooth list animations
            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutQuad }
                NumberAnimation { property: "y"; from: -20; duration: 300; easing.type: Easing.OutBack }
            }
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutQuad }
            }

            delegate: Rectangle {
                width: stationList.width
                height: 64
                radius: radiusSmall
                color: index === RadioController.selectedIndex
                    ? (typeof mainRoot !== "undefined" && !mainRoot.isNightMode ? Qt.rgba(radioCardContainer.colorAccent.r, radioCardContainer.colorAccent.g, radioCardContainer.colorAccent.b, 0.15) : "#2a3347")
                    : (typeof mainRoot !== "undefined" && !mainRoot.isNightMode ? Qt.rgba(0, 0, 0, 0.03) : Qt.rgba(0.17, 0.15, 0.22, 0.5))
                border.color: index === RadioController.selectedIndex ? colorAccent : colorStroke
                border.width: 1

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    // Station Logo with robust fallback
                    Rectangle {
                        width: 44
                        height: 44
                        radius: 8
                        color: "#15141a"
                        clip: true
                        
                        Image {
                            id: stationLogo
                            anchors.fill: parent
                            source: model.favicon !== "" ? model.favicon : "qrc:/cover_placeholder.png"
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            
                            onStatusChanged: {
                                if (status === Image.Error) {
                                    source = "qrc:/cover_placeholder.png"
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: name
                            color: colorTextPrimary
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: country + " - " + codec + " - " + bitrate + " kbps"
                            color: index === RadioController.selectedIndex ? colorAccentAlt : colorTextSubtle
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    MediaButton {
                        iconSource: index === RadioController.selectedIndex && RadioController.playbackStatus === "playing" ? "qrc:/Assets/Media/pause-svgrepo-com.svg" : "qrc:/Assets/Media/play-svgrepo-com.svg"
                        size: 44
                        iconSize: 18
                        fillColor: index === RadioController.selectedIndex ? colorAccent : colorSurfaceAlt
                        textColor: index === RadioController.selectedIndex ? "#c80e0a17" : radioCardContainer.colorTextPrimary

                        onClicked: {
                            if (index === RadioController.selectedIndex && RadioController.playbackStatus === "playing") {
                                RadioController.pause()
                            } else {
                                RadioController.playStation(index)
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            MediaButton {
                text: "Search"
                size: 54
                textSize: 12
                fillColor: radioCardContainer.colorSurfaceAlt
                onClicked: radioCardContainer.applyRadioFilters()
            }

            RowLayout {
                spacing: 8
                Text { text: "Volume"; color: colorTextSubtle; font.pixelSize: 12 }
                Slider {
                    id: radioVolumeSlider
                    Layout.preferredWidth: 180
                    from: 0
                    to: 100
                    stepSize: 1
                    implicitHeight: 24
                    Binding {
                        target: radioVolumeSlider
                        property: "value"
                        value: RadioController.volume
                        when: !radioVolumeSlider.pressed
                    }
                    onMoved: RadioController.setVolume(Math.round(value))
                    background: Rectangle {
                        x: 0
                        y: (parent.height - height) / 2
                        width: parent.width
                        height: 6
                        radius: 3
                        color: radioCardContainer.colorStroke
                        border.color: colorStroke

                        Rectangle {
                            width: parent.width * radioVolumeSlider.visualPosition
                            height: parent.height
                            radius: parent.radius
                            color: colorAccentAlt
                        }
                    }
                    handle: Rectangle {
                        x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                        width: 16
                        height: 16
                        radius: 8
                        color: colorSurface
                        border.color: colorAccentAlt
                        border.width: 2

                        Rectangle {
                            anchors.centerIn: parent
                            width: 6
                            height: 6
                            radius: 3
                            color: colorAccentAlt
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                spacing: 10
                MediaButton {
                    iconSource: RadioController.playbackStatus === "playing" ? "qrc:/Assets/Media/pause-svgrepo-com.svg" : "qrc:/Assets/Media/play-svgrepo-com.svg"
                    size: 58
                    iconSize: 24
                    fillColor: radioCardContainer.colorSurfaceAlt
                    onClicked: RadioController.playbackStatus === "playing" ? RadioController.pause() : RadioController.play()
                }
                MediaButton {
                    text: "Stop"
                    size: 52
                    textSize: 12
                    onClicked: RadioController.stop()
                }
            }
        }
    }

    Component.onCompleted: {
        RadioController.searchStationsAdvanced("", "lofi", "", "english")
    }

    Connections {
        target: RadioController
        function onTagsChanged() {
            let tagIndex = RadioController.tags.indexOf("lofi")
            if (tagIndex >= 0) tagBox.currentIndex = tagIndex
        }
    }
}
