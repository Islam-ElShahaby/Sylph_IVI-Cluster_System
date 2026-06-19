import QtQuick
import QtQuick.Effects

Item {
    id: root
    width: 140
    height: 90

    property string label: "LABEL"
    property color iconColor1: "#ff4444"
    property color iconColor2: "#ff6644"
    property string type: "seat" // "seat" or "vent"
    property int level: 0 // 0-3
    property bool mirrorIcon: false

    // Theme tokens
    property bool isNightMode: typeof mainRoot !== "undefined" ? mainRoot.isNightMode : true

    Column {
        anchors.centerIn: parent
        spacing: 8

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 80
            height: 56

            // Single SVG representation for the heated seat (much bigger!)
            Image {
                id: seatSvgImg
                anchors.centerIn: parent
                width: 56
                height: 56
                visible: false
                mirror: root.mirrorIcon
                source: root.type === "seat" ? "qrc:/Assets/Climate/heatedSeat-level" + root.level + ".svg" : ""
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }

            MultiEffect {
                id: seatSvgEffect
                source: seatSvgImg
                anchors.fill: seatSvgImg
                visible: root.type === "seat"
                colorization: 1.0
                brightness: 1.0
                // When level > 0, use a warm red/orange accent. Otherwise use a muted slate
                // color -- darker + more opaque in day mode so it stays legible on the light bg.
                colorizationColor: root.level > 0
                    ? root.iconColor1
                    : (root.isNightMode ? "#9690b0" : "#6c6880")
                opacity: root.level > 0 ? 1.0 : (root.isNightMode ? 0.5 : 0.6)

                Behavior on colorizationColor { ColorAnimation { duration: 250 } }
                Behavior on opacity { NumberAnimation { duration: 250 } }
            }

            // Row with Canvas drawings for the ventilation
            Row {
                anchors.centerIn: parent
                spacing: 4
                visible: root.type !== "seat"

                // Icon 1 (Ventilation Fan)
                Canvas {
                    id: icon1Canvas
                    width: 32
                    height: 32
                    visible: root.type !== "seat"
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        var alpha = root.level > 0 ? (0.4 + root.level * 0.2) : 0.3;
                        var c = root.iconColor1;

                        // Ventilation fan icon
                        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, alpha);
                        ctx.lineWidth = 2;
                        ctx.lineCap = "round";

                        ctx.save();
                        ctx.translate(16, 16);
                        for (var j = 0; j < 4; j++) {
                            ctx.rotate(Math.PI / 2);
                            ctx.beginPath();
                            ctx.moveTo(0, 0);
                            ctx.quadraticCurveTo(6, -4, 10, 0);
                            ctx.stroke();
                        }
                        ctx.restore();
                    }

                    Connections {
                        target: root
                        function onLevelChanged() { if (root.type !== "seat") icon1Canvas.requestPaint() }
                    }
                }

                // Icon 2 (Ventilation Arrows)
                Canvas {
                    id: icon2Canvas
                    width: 32
                    height: 32
                    visible: root.type !== "seat"
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        var alpha = root.level > 0 ? (0.4 + root.level * 0.2) : 0.3;
                        var c = root.iconColor2;

                        // Air direction arrows
                        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, alpha);
                        ctx.lineWidth = 2;
                        ctx.lineCap = "round";

                        for (var i = 0; i < 3; i++) {
                            var y = 8 + i * 8;
                            ctx.beginPath();
                            ctx.moveTo(6, y);
                            ctx.lineTo(26, y);
                            ctx.moveTo(22, y - 3);
                            ctx.lineTo(26, y);
                            ctx.lineTo(22, y + 3);
                            ctx.stroke();
                        }
                    }

                    Connections {
                        target: root
                        function onLevelChanged() { if (root.type !== "seat") icon2Canvas.requestPaint() }
                    }
                }
            }
        }

        Text {
            text: root.label
            color: root.isNightMode ? "#aaaacc" : "#5c5870"
            font.pixelSize: 11
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.level = (root.level + 1) % 4
        }
    }
}
