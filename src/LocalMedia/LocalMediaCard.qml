import QtQuick
import QtQml
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Sylph.LocalMedia 1.0

Item {
    id: localMediaCard

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

    function formatTime(ms) {
        let totalSeconds = Math.floor(ms / 1000)
        let minutes = Math.floor(totalSeconds / 60)
        let seconds = totalSeconds % 60
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // -- Now-playing header --
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: LocalMediaController.currentTitle
                        color: colorTextPrimary
                        font.pixelSize: 20
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: LocalMediaController.currentArtist !== "" ? LocalMediaController.currentArtist : "Unknown Artist"
                        color: colorTextMuted
                        font.pixelSize: 14
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Text {
                    text: "Tracks: " + LocalMediaController.trackCount
                    color: colorTextSubtle
                    font.pixelSize: 12
                }
            }

            // Progress bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text { text: formatTime(LocalMediaController.position); color: colorTextMuted; font.pixelSize: 11 }

                Item {
                    id: progressBar
                    Layout.fillWidth: true
                    implicitHeight: 14
                    readonly property real progress: LocalMediaController.duration > 0
                        ? LocalMediaController.position / LocalMediaController.duration : 0

                    Rectangle {
                        id: progressTrack
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 6
                        radius: 3
                        color: localMediaCard.colorStroke
                        border.color: colorStroke
                    }

                    Rectangle {
                        anchors.left: progressTrack.left
                        anchors.verticalCenter: progressTrack.verticalCenter
                        width: progressTrack.width * progressBar.progress
                        height: progressTrack.height
                        radius: progressTrack.radius
                        color: colorAccent
                        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    }
                }

                Text { text: formatTime(LocalMediaController.duration); color: colorTextMuted; font.pixelSize: 11 }
            }

            // Error display
            Text {
                text: LocalMediaController.lastError
                color: "#ff8e8e"
                font.pixelSize: 12
                visible: LocalMediaController.lastError !== ""
                Layout.fillWidth: true
            }
        }

        // -- Track list --
        ListView {
            id: trackList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: LocalMediaController.tracksModel
            spacing: 8
            clip: true

            Text {
                anchors.centerIn: parent
                text: LocalMediaController.scanning ? "Scanning for media…" : "No tracks found. Hit Scan to search."
                color: colorTextSubtle
                font.pixelSize: 12
                visible: trackList.count === 0
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
                width: trackList.width
                height: 60
                radius: radiusSmall
                color: index === LocalMediaController.currentIndex
                    ? (typeof mainRoot !== "undefined" && !mainRoot.isNightMode ? Qt.rgba(localMediaCard.colorAccent.r, localMediaCard.colorAccent.g, localMediaCard.colorAccent.b, 0.15) : "#2a3347")
                    : (typeof mainRoot !== "undefined" && !mainRoot.isNightMode ? Qt.rgba(0, 0, 0, 0.03) : Qt.rgba(0.17, 0.15, 0.22, 0.5))
                border.color: index === LocalMediaController.currentIndex ? colorAccent : colorStroke
                border.width: 1

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    // Music note icon
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 8
                        color: "#15141a"

                        Text {
                            anchors.centerIn: parent
                            text: "M"
                            font.pixelSize: 20
                            color: index === LocalMediaController.currentIndex ? colorAccent : colorTextSubtle
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    // Track info
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: model.title !== "" ? model.title : model.fileName
                            color: colorTextPrimary
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        RowLayout {
                            spacing: 6
                            Text {
                                text: model.artist !== "" ? model.artist : model.fileName
                                color: index === LocalMediaController.currentIndex ? colorAccentAlt : colorTextSubtle
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }

                            // Source badge
                            Rectangle {
                                width: badgeText.implicitWidth + 12
                                height: 18
                                radius: 9
                                color: model.source === "usb" ? Qt.rgba(0.48, 0.89, 1.0, 0.15) : Qt.rgba(0.72, 0.95, 0.43, 0.15)
                                border.color: model.source === "usb" ? Qt.rgba(0.48, 0.89, 1.0, 0.3) : Qt.rgba(0.72, 0.95, 0.43, 0.3)
                                border.width: 1

                                Text {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: model.source === "usb" ? "USB" : "Local"
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: model.source === "usb" ? colorAccentAlt : colorAccent
                                }
                            }
                        }
                    }

                    // Save to local button (only for USB tracks not yet saved)
                    MediaButton {
                        visible: model.source === "usb" && !model.isSaved
                        text: "+"
                        size: 36
                        textSize: 18
                        fillColor: Qt.rgba(0.48, 0.89, 1.0, 0.15)
                        textColor: colorAccentAlt

                        onClicked: LocalMediaController.saveToLocal(index)
                    }

                    // Saved indicator (replaces + button after saving)
                    Rectangle {
                        visible: model.source === "usb" && model.isSaved
                        width: 36
                        height: 36
                        radius: 18
                        color: Qt.rgba(0.72, 0.95, 0.43, 0.15)

                        Text {
                            anchors.centerIn: parent
                            text: "OK"
                            font.pixelSize: 16
                            color: colorAccent
                        }
                    }

                    // Play/Pause button
                    MediaButton {
                        iconSource: index === LocalMediaController.currentIndex && LocalMediaController.playbackStatus === "playing"
                            ? "qrc:/Assets/Media/pause-svgrepo-com.svg"
                            : "qrc:/Assets/Media/play-svgrepo-com.svg"
                        size: 40
                        iconSize: 16
                        fillColor: index === LocalMediaController.currentIndex ? colorAccent : colorSurfaceAlt
                        textColor: index === LocalMediaController.currentIndex ? "#c80e0a17" : localMediaCard.colorTextPrimary

                        onClicked: {
                            if (index === LocalMediaController.currentIndex && LocalMediaController.playbackStatus === "playing") {
                                LocalMediaController.pause()
                            } else {
                                LocalMediaController.playTrack(index)
                            }
                        }
                    }
                }
            }
        }

        // -- Bottom controls bar --
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            // Scan button
            MediaButton {
                text: LocalMediaController.scanning ? "…" : "Scan"
                size: 54
                textSize: 12
                fillColor: localMediaCard.colorSurfaceAlt
                enabled: !LocalMediaController.scanning
                onClicked: LocalMediaController.scanMedia()
            }

            // Volume slider
            RowLayout {
                spacing: 8
                Text { text: "Volume"; color: colorTextSubtle; font.pixelSize: 12 }
                Slider {
                    id: localVolumeSlider
                    Layout.preferredWidth: 140
                    from: 0
                    to: 100
                    stepSize: 1
                    implicitHeight: 24
                    Binding {
                        target: localVolumeSlider
                        property: "value"
                        value: LocalMediaController.volume
                        when: !localVolumeSlider.pressed
                    }
                    onMoved: LocalMediaController.setVolume(Math.round(value))
                    background: Rectangle {
                        x: 0
                        y: (parent.height - height) / 2
                        width: parent.width
                        height: 6
                        radius: 3
                        color: localMediaCard.colorStroke
                        border.color: colorStroke

                        Rectangle {
                            width: parent.width * localVolumeSlider.visualPosition
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

            // Playback controls
            RowLayout {
                spacing: 8

                // Shuffle toggle
                MediaButton {
                    iconSource: "qrc:/Assets/Media/shuffle-svgrepo-com.svg"
                    size: 44
                    iconSize: 18
                    fillColor: LocalMediaController.shuffle ? colorAccent : colorSurfaceAlt
                    textColor: LocalMediaController.shuffle ? "#c80e0a17" : colorTextPrimary
                    onClicked: LocalMediaController.setShuffle(!LocalMediaController.shuffle)
                }

                MediaButton {
                    iconSource: "qrc:/Assets/Media/skip-previous-svgrepo-com.svg"
                    size: 48
                    iconSize: 18
                    onClicked: LocalMediaController.previous()
                }
                MediaButton {
                    iconSource: LocalMediaController.playbackStatus === "playing"
                        ? "qrc:/Assets/Media/pause-svgrepo-com.svg"
                        : "qrc:/Assets/Media/play-svgrepo-com.svg"
                    size: 58
                    iconSize: 24
                    fillColor: localMediaCard.colorSurfaceAlt
                    onClicked: LocalMediaController.playbackStatus === "playing"
                        ? LocalMediaController.pause() : LocalMediaController.play()
                }
                MediaButton {
                    iconSource: "qrc:/Assets/Media/skip-next-svgrepo-com.svg"
                    size: 48
                    iconSize: 18
                    onClicked: LocalMediaController.next()
                }
            }
        }
    }

    Component.onCompleted: {
        LocalMediaController.scanMedia()
    }
}
