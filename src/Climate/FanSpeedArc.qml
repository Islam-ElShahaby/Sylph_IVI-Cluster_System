import QtQuick
import QtQuick.Effects

Item {
    id: root

    // CRITICAL: Required to prevent RowLayout recursive rearrange loops
    implicitWidth: 360
    implicitHeight: 180

    property int currentSpeed: 4
    property int maxSpeed: 6

    property real arcStartDeg: -130
    property real arcEndDeg: -50
    property real arcInnerRadius: 240
    property real arcOuterRadius: 300
    property real arcCenterYOffset: 350
    property real arcGapAngle: 0.02
    property int iconSize: 18

    // NOT bound to `currentSpeed`: a live binding would snap animatedSpeed to
    // the new value while speedAnim is still animating from the old one,
    // causing a jump-then-rewind glitch. Seeded once, then driven by speedAnim.
    property real animatedSpeed
    property bool isNightMode: typeof mainRoot !== "undefined" ? mainRoot.isNightMode : true
    property color accentColor: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"

    onAccentColorChanged: arcCanvas.requestPaint()

    Component.onCompleted: { speedAnim.stop(); animatedSpeed = currentSpeed }

    property bool useOptimizedCanvas: true

    readonly property real startAngleRad: arcStartDeg * Math.PI / 180
    readonly property real endAngleRad: arcEndDeg * Math.PI / 180
    readonly property real totalAngleRad: endAngleRad - startAngleRad
    readonly property real segmentAngleRad: (totalAngleRad - (arcGapAngle * (maxSpeed - 1))) / maxSpeed

    Canvas {
        id: arcCanvas
        x: -40
        y: 0
        width: parent.width + 80
        height: parent.height

        renderTarget: root.useOptimizedCanvas ? Canvas.FramebufferObject : Canvas.Image
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var centerX = width / 2;
            var centerY = root.arcCenterYOffset;
            var r1 = root.arcInnerRadius;
            var r2 = root.arcOuterRadius;
            var midR = (r1 + r2) / 2;
            var cr = 5;

            // Whole gauge is tinted with the app accent so it matches the dials.
            // Day mode needs a touch more alpha to stay legible on the light bg.
            var fillInactiveAlpha   = root.isNightMode ? 0.14 : 0.12;
            var fillActiveAlpha     = root.isNightMode ? 0.42 : 0.32;
            var strokeInactiveAlpha = root.isNightMode ? 0.28 : 0.22;
            var strokeActiveAlpha   = root.isNightMode ? 0.80 : 0.60;
            var ac = root.accentColor;
            var accentRgb = Math.round(ac.r * 255) + "," + Math.round(ac.g * 255) + "," + Math.round(ac.b * 255);
            var fillRgb   = accentRgb;
            var strokeRgb = accentRgb;

            function drawSegmentPath(sA, eA) {
                var midAngle = (sA + eA) / 2;
                var span  = eA - sA;
                var halfH = (r2 - r1) / 2;
                var halfWi = r1 * span / 2;
                var halfWo = r2 * span / 2;
                var c = Math.min(cr, halfWi * 0.45, halfH * 0.45);

                ctx.save();
                ctx.translate(centerX + midR * Math.cos(midAngle),
                              centerY + midR * Math.sin(midAngle));
                ctx.rotate(midAngle + Math.PI / 2);

                ctx.beginPath();
                ctx.moveTo(-halfWi + c, halfH);
                ctx.arcTo( halfWi,  halfH,  halfWo, -halfH, c);
                ctx.arcTo( halfWo, -halfH, -halfWo, -halfH, c);
                ctx.arcTo(-halfWo, -halfH, -halfWi,  halfH, c);
                ctx.arcTo(-halfWi,  halfH, -halfWi + c, halfH, c);
                ctx.closePath();

                ctx.restore();
            }

            for (var i = 0; i < root.maxSpeed; i++) {
                var sAngle = root.startAngleRad + i * (root.segmentAngleRad + root.arcGapAngle);
                var eAngle = sAngle + root.segmentAngleRad;

                var activeAmount = Math.max(0, Math.min(1, root.animatedSpeed - i));
                var fillAlpha   = fillInactiveAlpha   + (fillActiveAlpha   - fillInactiveAlpha)   * activeAmount;
                var strokeAlpha = strokeInactiveAlpha + (strokeActiveAlpha - strokeInactiveAlpha) * activeAmount;

                drawSegmentPath(sAngle, eAngle);

                // First and last segments get an internal gradient fade (edge -> full color).
                // All other segments use solid fill/stroke.
                if (i === 0 || i === root.maxSpeed - 1) {
                    var gx0 = centerX + midR * Math.cos(sAngle);
                    var gy0 = centerY + midR * Math.sin(sAngle);
                    var gx1 = centerX + midR * Math.cos(eAngle);
                    var gy1 = centerY + midR * Math.sin(eAngle);

                    var solidFill   = "rgba(" + fillRgb   + "," + fillAlpha   + ")";
                    var solidStroke = "rgba(" + strokeRgb + "," + strokeAlpha + ")";
                    var transFill   = "rgba(" + fillRgb   + ",0)";
                    var transStroke = "rgba(" + strokeRgb + ",0)";

                    var fGrad = ctx.createLinearGradient(gx0, gy0, gx1, gy1);
                    var sGrad = ctx.createLinearGradient(gx0, gy0, gx1, gy1);

                    if (i === 0) {
                        // First segment: fades in left-to-right
                        fGrad.addColorStop(0, transFill);
                        fGrad.addColorStop(1, solidFill);
                        sGrad.addColorStop(0, transStroke);
                        sGrad.addColorStop(1, solidStroke);
                    } else {
                        // Last segment: fades out left-to-right
                        fGrad.addColorStop(0, solidFill);
                        fGrad.addColorStop(1, transFill);
                        sGrad.addColorStop(0, solidStroke);
                        sGrad.addColorStop(1, transStroke);
                    }

                    ctx.fillStyle   = fGrad;
                    ctx.strokeStyle = sGrad;
                } else {
                    ctx.fillStyle   = "rgba(" + fillRgb   + "," + fillAlpha   + ")";
                    ctx.strokeStyle = "rgba(" + strokeRgb + "," + strokeAlpha + ")";
                }

                ctx.fill();
                ctx.lineWidth = 1.2;
                ctx.stroke();
            }

            // Second pass: bright glow on the selected segment. Tracks the
            // animated speed (rounded) so the highlight glides between
            // segments along with the fill instead of snapping ahead of it.
            var glowSpeed = Math.round(root.animatedSpeed);
            if (glowSpeed > 0) {
                var gi  = glowSpeed - 1;
                var gsA = root.startAngleRad + gi * (root.segmentAngleRad + root.arcGapAngle);
                var geA = gsA + root.segmentAngleRad;

                // Glow as widening strokes, NOT shadowBlur: this repaints every
                // frame of the speed animation, and shadowBlur is a CPU gaussian
                // pass that tanks the frame rate on the Pi.
                drawSegmentPath(gsA, geA);
                ctx.fillStyle   = "rgba(" + accentRgb + "," + (root.isNightMode ? 0.32 : 0.28) + ")";
                ctx.fill();
                ctx.strokeStyle = "rgba(" + accentRgb + ",0.18)";
                ctx.lineWidth = 7;
                ctx.stroke();
                ctx.strokeStyle = "rgba(" + accentRgb + ",0.45)";
                ctx.lineWidth = 4;
                ctx.stroke();
                ctx.strokeStyle = "rgba(" + accentRgb + ",0.90)";
                ctx.lineWidth = 2;
                ctx.stroke();
            }
        }

        MouseArea {
            anchors.fill: parent

            property int  previousSpeed: 0
            property bool hasDragged: false
            property bool pressedOnArc: false

            function segmentAt(mouse) {
                var cx   = width / 2;
                var cy   = root.arcCenterYOffset;
                var dx   = mouse.x - cx;
                var dy   = mouse.y - cy;
                var dist = Math.sqrt(dx * dx + dy * dy);
                if (dist < root.arcInnerRadius || dist > root.arcOuterRadius) return -1;
                var angle = Math.atan2(dy, dx);
                if (angle < root.startAngleRad || angle > root.endAngleRad) return -1;
                var relativeAngle = angle - root.startAngleRad;
                var segmentSpan   = root.segmentAngleRad + root.arcGapAngle;
                if ((relativeAngle % segmentSpan) > root.segmentAngleRad) return -1;
                var index = Math.floor(relativeAngle / segmentSpan);
                return (index >= 0 && index < root.maxSpeed) ? index : -1;
            }

            onPressed: function(mouse) {
                hasDragged    = false;
                previousSpeed = root.currentSpeed;
                var idx = segmentAt(mouse);
                if (idx >= 0) {
                    pressedOnArc = true;
                    root.currentSpeed = idx + 1;
                } else {
                    pressedOnArc = false;
                }
            }

            onPositionChanged: function(mouse) {
                hasDragged     = true;
                root.isDragging = true;
                var idx = segmentAt(mouse);
                if (idx >= 0) root.currentSpeed = idx + 1;
            }

            onReleased: function(mouse) {
                root.isDragging = false;
                // Toggle off only when tapping the already-selected segment without dragging
                if (pressedOnArc && !hasDragged && root.currentSpeed === previousSpeed) {
                    root.currentSpeed = 0;
                }
            }
        }
    }

    Repeater {
        model: root.maxSpeed

        Item {
            property real dynamicSize: root.iconSize * (0.5 + 0.5 * index / Math.max(1, root.maxSpeed - 1))
            width:  dynamicSize
            height: dynamicSize

            property real activeAmount: Math.max(0, Math.min(1, root.animatedSpeed - index))

            property real sAngle:      root.startAngleRad + index * (root.segmentAngleRad + root.arcGapAngle)
            property real midAngleRad: sAngle + root.segmentAngleRad / 2
            property real iconRadius:  (root.arcInnerRadius + root.arcOuterRadius) / 2 + 6

            x: root.width / 2 + iconRadius * Math.cos(midAngleRad) - width / 2
            y: root.arcCenterYOffset  + iconRadius * Math.sin(midAngleRad) - height / 2

            Image {
                id: fanImg
                anchors.fill: parent
                source: "qrc:/Assets/Climate/fan-blades-icon.svg"
                sourceSize: Qt.size(dynamicSize, dynamicSize)
                mipmap: true
                visible: false
            }

            MultiEffect {
                source: fanImg
                anchors.fill: fanImg
                opacity: (root.isNightMode ? 0.4 : 0.5) + (root.isNightMode ? 0.6 : 0.5) * activeAmount
                colorization: 1.0
                brightness: 1.0
                colorizationColor: activeAmount > 0.5
                    ? (root.isNightMode ? "#ffffff" : Qt.darker(root.accentColor, 1.4))
                    : (root.isNightMode ? "#8088a0" : "#6c5a96")
            }
        }
    }

    // Fan icons stay still by design. The blades used to spin via an
    // infinite animation, but that re-rendered every icon's MultiEffect
    // every frame forever -- a constant CPU/GPU drain -- so it's gone.

    property bool isDragging: false

    NumberAnimation {
        id: speedAnim
        target: root
        property: "animatedSpeed"
        easing.type: Easing.InOutCubic
    }

    onCurrentSpeedChanged: {
        speedAnim.stop()
        speedAnim.from     = root.animatedSpeed
        speedAnim.to       = currentSpeed
        speedAnim.duration = root.isDragging ? 0 : 380
        speedAnim.start()
        arcCanvas.requestPaint()
    }
    onAnimatedSpeedChanged: arcCanvas.requestPaint()
    onIsNightModeChanged:   arcCanvas.requestPaint()
}
