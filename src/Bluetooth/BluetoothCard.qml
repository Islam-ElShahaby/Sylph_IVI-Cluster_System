import QtQuick
import QtQml
import QtQuick.Controls
import QtQuick.Layouts
import Sylph.Bluetooth 1.0

Item {
    id: audioCard

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
        spacing: 16


        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: BtController.trackTitle
                    color: colorTextPrimary
                    font.pixelSize: 24
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: BtController.artist
                    color: colorTextMuted
                    font.pixelSize: 16
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: BtController.album !== "" ? BtController.album : "Unknown Album"
                    color: colorTextSubtle
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text { text: formatTime(BtController.position); color: colorTextMuted; font.pixelSize: 12 }
                    Item {
                        id: btProgressBar
                        Layout.fillWidth: true
                        implicitHeight: 14
                        readonly property real progress: BtController.duration > 0 ? BtController.position / BtController.duration : 0

                        Rectangle {
                            id: btProgressTrack
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 6
                            radius: 3
                            color: audioCard.colorStroke
                            border.color: colorStroke
                        }

                        Rectangle {
                            anchors.left: btProgressTrack.left
                            anchors.verticalCenter: btProgressTrack.verticalCenter
                            width: btProgressTrack.width * btProgressBar.progress
                            height: btProgressTrack.height
                            radius: btProgressTrack.radius
                            color: colorAccent
                            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        }
                    }
                    Text { text: formatTime(BtController.duration); color: colorTextMuted; font.pixelSize: 12 }
                }
            }

            Rectangle {
                Layout.preferredWidth: 140
                Layout.preferredHeight: 140
                radius: radiusSmall
                color: colorSurfaceAlt
                border.color: colorStroke
                border.width: 1
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: !BtController.connected ? 20 : 0
                    source: !BtController.connected ? "qrc:/Assets/Bluetooth/bluetooth-slash-svgrepo-com.svg" : (BtController.coverArt !== "" ? BtController.coverArt : "qrc:/cover_placeholder.png")
                    fillMode: !BtController.connected ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                    cache: false
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: colorStroke
            opacity: 0.6
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            RowLayout {
                spacing: 8
                Text { text: "Volume"; color: colorTextSubtle; font.pixelSize: 12 }
                Slider {
                    id: btVolumeSlider
                    Layout.preferredWidth: 180
                    from: 0
                    to: 100
                    stepSize: 1
                    implicitHeight: 24
                    Binding {
                        target: btVolumeSlider
                        property: "value"
                        value: BtController.volume
                        when: !btVolumeSlider.pressed
                    }
                    onMoved: BtController.setVolume(Math.round(value))
                    background: Rectangle {
                        x: 0
                        y: (parent.height - height) / 2
                        width: parent.width
                        height: 6
                        radius: 3
                        color: audioCard.colorStroke
                        border.color: colorStroke

                        Rectangle {
                            width: parent.width * btVolumeSlider.visualPosition
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
                    iconSource: "qrc:/Assets/Media/skip-previous-svgrepo-com.svg"
                    size: 52
                    iconSize: 20
                    onClicked: BtController.previous()
                }
                MediaButton {
                    iconSource: BtController.playbackStatus === "playing" ? "qrc:/Assets/Media/pause-svgrepo-com.svg" : "qrc:/Assets/Media/play-svgrepo-com.svg"
                    size: 62
                    iconSize: 26
                    fillColor: audioCard.colorSurfaceAlt
                    onClicked: BtController.playbackStatus === "playing" ? BtController.pause() : BtController.play()
                }
                MediaButton {
                    iconSource: "qrc:/Assets/Media/skip-next-svgrepo-com.svg"
                    size: 52
                    iconSize: 20
                    onClicked: BtController.next()
                }
            }
        }
    }
}
