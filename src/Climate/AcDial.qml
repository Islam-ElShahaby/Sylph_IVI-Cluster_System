import QtQuick

Item {
    id: root

    implicitWidth: 200
    implicitHeight: 200

    property color dialColor: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"
    property real  temperature: 22
    property real  minTemp: 16
    property real  maxTemp: 30
    property bool  isNightMode: typeof mainRoot !== "undefined" ? mainRoot.isNightMode : true
    property bool  flipArc:  false   // true -> mirror arc to right semicircle (passenger)
    property bool  disabled: false   // true -> fade out slider arc + hide dot, block interaction

    // displayTemp follows temperature -- instant during drag, animated otherwise.
    // Deliberately NOT bound to `temperature`: a live binding would snap
    // displayTemp straight to the new value while tempAnim is still animating
    // from the old one, producing a jump-then-rewind glitch. It is seeded once
    // (Component.onCompleted) and thereafter driven only by tempAnim / drag.
    property real  displayTemp
    property bool  _dragging:   false

    Component.onCompleted: { tempAnim.stop(); displayTemp = temperature }

    // arcOpacity drives the slider-arc / dot fade when disabled
    property real  arcOpacity: 1.0

    // Extra pixels the arcCanvas bleeds beyond the Item on every side so that
    // the 13 px dot halo at the arc's top/bottom extremes isn't clipped.
    // maxR in that canvas is clamped to root.width/2 so arc geometry is unchanged.
    readonly property real _ovf: 16

    // sliderOpacity dims just the slider (arc + track + dot) without touching
    // the temperature readout -- used to mark the passenger dial as synced.
    property real  sliderOpacity: 1.0
    Behavior on sliderOpacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

    NumberAnimation {
        id: tempAnim
        target: root; property: "displayTemp"
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: arcOpacityAnim
        target: root; property: "arcOpacity"
        duration: 280; easing.type: Easing.InOutQuad
    }

    function _updateArcOpacity() {
        arcOpacityAnim.stop()
        arcOpacityAnim.to = (root.acOn && !root.disabled) ? 1.0 : 0.0
        arcOpacityAnim.start()
    }

    onDisabledChanged: _updateArcOpacity()
    onAcOnChanged: {
        _updateArcOpacity()
        acOnAnim.stop()
        acOnAnim.to = root.acOn ? 1.0 : 0.0
        acOnAnim.start()
    }

    onTemperatureChanged: {
        tempAnim.stop()
        tempAnim.from     = root.displayTemp
        tempAnim.to       = temperature
        tempAnim.duration = root._dragging ? 0 : 220
        tempAnim.start()
    }

    // Accent segments glow when A/C is on -- fades smoothly on toggle
    property bool acOn:      true
    property real acOnAlpha: 1.0

    NumberAnimation {
        id: acOnAnim
        target: root; property: "acOnAlpha"
        duration: 300; easing.type: Easing.InOutQuad
    }

    // -- Repaint routing --
    //  Canvases repaint ONLY when their drawn *shape* changes:
    //    - displayTemp (drag)  -> arcCanvas
    //    - theme / accent colour -> all three
    //  Every on/off fade (A/C toggle, disable) is a composited Item.opacity
    //  animation via each layer's `opacity:` binding below -- so toggling A/C
    //  performs ZERO canvas repaints and stays at full frame rate.
    onDisplayTempChanged: arcCanvas.requestPaint()

    onDialColorChanged:   { bgCanvas.requestPaint(); glowCanvas.requestPaint(); arcCanvas.requestPaint() }
    onIsNightModeChanged: { bgCanvas.requestPaint(); glowCanvas.requestPaint(); arcCanvas.requestPaint() }

    // ============================================================
    //  STATIC BASE LAYER  (never repaints on a toggle)
    //  Glass dome, gradients, decorative rim and the faint inactive
    //  segment backdrop. Repaints only on theme / accent changes.
    // ============================================================
    Canvas {
        id: bgCanvas
        anchors.fill: parent
        renderTarget:   Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var cx   = width  / 2;
            var cy   = height / 2;
            var maxR = Math.min(cx, cy);

            // -- Helper: create a colour from dialColor with custom alpha --
            var dc = root.dialColor;
            function ac(alpha) { return Qt.rgba(dc.r, dc.g, dc.b, alpha); }

            // -- Radii --
            var segOuterR  = maxR * 0.78;
            var segInnerR  = maxR * 0.66;
            var rimR       = maxR * 0.60;
            var glassR     = maxR * 0.54;

            // -- Mirror for passenger dial --
            if (root.flipArc) {
                ctx.save();
                ctx.translate(cx, 0);
                ctx.scale(-1, 1);
                ctx.translate(-cx, 0);
            }

            // ============================================
            // SEGMENTED GAUGE RING -- faint inactive backdrop (12 segments).
            // The accent glow that rides on top lives on glowCanvas.
            // ============================================
            var numSeg  = 12;
            var slotAng = (2 * Math.PI) / numSeg;   // 30 deg per slot
            var segSpan = slotAng * 0.75;            // 22.5 deg active, 7.5 deg gap

            ctx.fillStyle = root.isNightMode ? "rgba(255,255,255,0.05)" : "rgba(0,0,0,0.04)";
            for (var j = 0; j < numSeg; j++) {
                var slotStart = j * slotAng;
                var sA        = slotStart + slotAng * 0.125;
                var eA        = sA + segSpan;

                ctx.beginPath();
                ctx.arc(cx, cy, segOuterR, sA, eA, false);
                ctx.arc(cx, cy, segInnerR, eA, sA, true);
                ctx.closePath();
                ctx.fill();
            }

            // ============================================
            // INNER DECORATIVE RIM
            // ============================================
            // Halo faked with a wide low-alpha stroke under the rim line --
            // canvas shadowBlur is a CPU gaussian pass, far too slow on the Pi.
            ctx.beginPath();
            ctx.arc(cx, cy, rimR, 0, 2 * Math.PI);
            ctx.strokeStyle = ac(0.10);
            ctx.lineWidth   = 5;
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(cx, cy, rimR, 0, 2 * Math.PI);
            ctx.strokeStyle = ac(0.30);
            ctx.lineWidth   = 1;
            ctx.stroke();

            // ============================================
            // GLASS DOME
            // ============================================
            var baseGrad = ctx.createRadialGradient(
                cx - glassR * 0.22, cy - glassR * 0.28, 0,
                cx, cy, glassR
            );

            if (root.isNightMode) {
                baseGrad.addColorStop(0.00, "rgba(52, 42, 90,  0.80)");
                baseGrad.addColorStop(0.28, "rgba(24, 18, 56,  0.90)");
                baseGrad.addColorStop(0.65, "rgba(12,  8, 32,  0.94)");
                baseGrad.addColorStop(1.00, "rgba(6,   3, 18,  0.97)");
            } else {
                baseGrad.addColorStop(0.00, "rgba(248, 245, 255, 0.90)");
                baseGrad.addColorStop(0.30, "rgba(235, 230, 252, 0.88)");
                baseGrad.addColorStop(0.70, "rgba(215, 208, 245, 0.91)");
                baseGrad.addColorStop(1.00, "rgba(195, 186, 235, 0.94)");
            }

            ctx.beginPath();
            ctx.arc(cx, cy, glassR, 0, 2 * Math.PI);
            ctx.fillStyle = baseGrad;
            ctx.fill();

            // Accent rim glow -- layered strokes instead of shadowBlur
            ctx.beginPath();
            ctx.arc(cx, cy, glassR, 0, 2 * Math.PI);
            ctx.strokeStyle = ac(root.isNightMode ? 0.16 : 0.12);
            ctx.lineWidth   = 7;
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(cx, cy, glassR, 0, 2 * Math.PI);
            ctx.strokeStyle = ac(root.isNightMode ? 0.32 : 0.26);
            ctx.lineWidth   = 3.5;
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(cx, cy, glassR, 0, 2 * Math.PI);
            ctx.strokeStyle = ac(root.isNightMode ? 0.55 : 0.50);
            ctx.lineWidth   = 1.8;
            ctx.stroke();

            // Caustic ring (glass refraction halo)
            ctx.beginPath();
            ctx.arc(cx, cy, glassR * 0.68, 0, 2 * Math.PI);
            ctx.strokeStyle = root.isNightMode ? "rgba(255,255,255,0.055)" : "rgba(255,255,255,0.20)";
            ctx.lineWidth   = 2.5;
            ctx.stroke();

            // Primary specular highlight (top-left)
            var specGrad = ctx.createRadialGradient(
                cx - glassR * 0.33, cy - glassR * 0.40, 1,
                cx - glassR * 0.05, cy - glassR * 0.06, glassR * 0.74
            );
            specGrad.addColorStop(0.00, root.isNightMode ? "rgba(255,255,255,0.46)" : "rgba(255,255,255,0.70)");
            specGrad.addColorStop(0.28, root.isNightMode ? "rgba(255,255,255,0.14)" : "rgba(255,255,255,0.25)");
            specGrad.addColorStop(1.00, "rgba(255,255,255,0.00)");

            ctx.beginPath();
            ctx.arc(cx, cy, glassR, 0, 2 * Math.PI);
            ctx.fillStyle = specGrad;
            ctx.fill();

            // Accent bounce light (bottom-right)
            var cyanRefl = ctx.createRadialGradient(
                cx + glassR * 0.22, cy + glassR * 0.30, 0,
                cx, cy, glassR
            );
            cyanRefl.addColorStop(0.0, ac(root.isNightMode ? 0.12 : 0.08));
            cyanRefl.addColorStop(1.0, ac(0.00));

            ctx.beginPath();
            ctx.arc(cx, cy, glassR, 0, 2 * Math.PI);
            ctx.fillStyle = cyanRefl;
            ctx.fill();

            if (root.flipArc) ctx.restore();
        }
    }

    // ============================================================
    //  SEGMENT-GLOW LAYER
    //  The accent segments at full intensity. The A/C on/off fade is a
    //  composited opacity animation here -- no repaint on toggle.
    // ============================================================
    Canvas {
        id: glowCanvas
        anchors.fill: parent
        anchors.margins: -root._ovf
        renderTarget:   Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative
        opacity: root.acOnAlpha

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var cx   = width  / 2;
            var cy   = height / 2;
            var maxR = Math.min(root.width, root.height) / 2;

            var dc = root.dialColor;
            function ac(alpha) { return Qt.rgba(dc.r, dc.g, dc.b, alpha); }

            var segOuterR = maxR * 0.78;
            var segInnerR = maxR * 0.66;

            if (root.flipArc) {
                ctx.save();
                ctx.translate(cx, 0);
                ctx.scale(-1, 1);
                ctx.translate(-cx, 0);
            }

            var numSeg  = 12;
            var slotAng = (2 * Math.PI) / numSeg;
            var segSpan = slotAng * 0.75;

            for (var j = 0; j < numSeg; j++) {
                var slotStart = j * slotAng;
                var midDeg = ((((slotStart + slotAng / 2) * 180 / Math.PI) % 360) + 360) % 360;

                // Accent zones: upper-left (225 deg +/- 30 deg) and lower-right (45 deg +/- 30 deg)
                if (!((midDeg >= 195 && midDeg <= 255) || (midDeg >= 15 && midDeg <= 75)))
                    continue;

                var sA = slotStart + slotAng * 0.125;
                var eA = sA + segSpan;

                // Halo: the same segment drawn slightly expanded at low alpha --
                // cheap stand-in for shadowBlur (CPU gaussian pass per fill)
                ctx.fillStyle = ac(0.20);
                ctx.beginPath();
                ctx.arc(cx, cy, segOuterR + 5, sA - 0.03, eA + 0.03, false);
                ctx.arc(cx, cy, Math.max(1, segInnerR - 5), eA + 0.03, sA - 0.03, true);
                ctx.closePath();
                ctx.fill();

                ctx.fillStyle = ac(0.90);
                ctx.beginPath();
                ctx.arc(cx, cy, segOuterR, sA, eA, false);
                ctx.arc(cx, cy, segInnerR, eA, sA, true);
                ctx.closePath();
                ctx.fill();
            }

            if (root.flipArc) ctx.restore();
        }
    }

    // ============================================================
    //  DYNAMIC FOREGROUND LAYER
    //  Slider track + moving temperature arc + indicator dot. This is
    //  the only canvas that repaints while dragging the temperature; its
    //  disable/off fade is a composited opacity animation (no repaint).
    // ============================================================
    Canvas {
        id: arcCanvas
        // Bleed _ovf px on all sides: FBO is larger than the Item so the glow
        // and dot halo at the arc extremes aren't clipped by the canvas edge.
        anchors.fill: parent
        anchors.margins: -root._ovf
        renderTarget:   Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative
        opacity: root.arcOpacity * root.sliderOpacity

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            // cx/cy are the center of the canvas == the center of the Item
            // maxR is tied to root's original size so arc geometry is unchanged.
            var cx   = width  / 2;
            var cy   = height / 2;
            var maxR = Math.min(root.width, root.height) / 2;

            var dc = root.dialColor;
            function ac(alpha) { return Qt.rgba(dc.r, dc.g, dc.b, alpha); }

            var sliderR = maxR * 0.90;

            // -- Mirror for passenger dial --
            if (root.flipArc) {
                ctx.save();
                ctx.translate(cx, 0);
                ctx.scale(-1, 1);
                ctx.translate(-cx, 0);
            }

            // -- Normalised temperature --
            var norm      = Math.max(0, Math.min(1, (root.displayTemp - root.minTemp) / (root.maxTemp - root.minTemp)));
            var arcStart  = Math.PI / 2;
            var arcFull   = 3 * Math.PI / 2;
            var activeEnd = arcStart + norm * Math.PI;

            // ============================================
            // SLIDER TRACK (faint full arc)
            // ============================================
            ctx.beginPath();
            ctx.arc(cx, cy, sliderR, arcStart, arcFull, false);
            ctx.strokeStyle = ac(0.07);
            ctx.lineWidth   = 2;
            ctx.stroke();

            // ============================================
            // ACTIVE SLIDER ARC
            // ============================================
            if (norm > 0.005) {
                // Glow as widening underlay strokes, NOT shadowBlur: this canvas
                // repaints every frame while dragging, and shadowBlur is a CPU
                // gaussian pass that tanks the frame rate on the Pi.
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.arc(cx, cy, sliderR, arcStart, activeEnd, false);
                ctx.strokeStyle = ac(0.16);
                ctx.lineWidth   = 8;
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(cx, cy, sliderR, arcStart, activeEnd, false);
                ctx.strokeStyle = ac(0.38);
                ctx.lineWidth   = 4.5;
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(cx, cy, sliderR, arcStart, activeEnd, false);
                ctx.strokeStyle = root.dialColor;
                ctx.lineWidth   = 2.5;
                ctx.stroke();
            }

            // ============================================
            // INDICATOR DOT
            // ============================================
            var dotX = cx + sliderR * Math.cos(activeEnd);
            var dotY = cy + sliderR * Math.sin(activeEnd);

            // Dot halo: concentric low-alpha discs instead of shadowBlur
            ctx.beginPath();
            ctx.arc(dotX, dotY, 13, 0, 2 * Math.PI);
            ctx.fillStyle = root.isNightMode ? "rgba(255,255,255,0.10)" : ac(0.10);
            ctx.fill();
            ctx.beginPath();
            ctx.arc(dotX, dotY, 8, 0, 2 * Math.PI);
            ctx.fillStyle = root.isNightMode ? "rgba(255,255,255,0.20)" : ac(0.18);
            ctx.fill();
            ctx.beginPath();
            ctx.arc(dotX, dotY, 4.5, 0, 2 * Math.PI);
            ctx.fillStyle = root.isNightMode ? "#ffffff" : root.dialColor;
            ctx.fill();

            ctx.beginPath();
            ctx.arc(dotX, dotY, 4.5, 0, 2 * Math.PI);
            ctx.strokeStyle = ac(0.90);
            ctx.lineWidth   = 1.5;
            ctx.stroke();

            if (root.flipArc) ctx.restore();
        }
    }

    // Temperature text -- above canvas in z-stack
    Column {
        anchors.centerIn: parent
        spacing: -2

        // Number <-> "--" crossfade slot (no hard swap on A/C toggle)
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width:  tempNumber.implicitWidth
            height: tempNumber.implicitHeight

            Text {
                id: tempNumber
                anchors.centerIn: parent
                text: Math.round(root.displayTemp).toString()
                color: root.isNightMode ? "#ffffff" : "#1a1824"
                font.pixelSize: root.width * 0.185
                font.bold: true
                opacity: root.acOn ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
            Text {
                anchors.centerIn: parent
                text: "--"
                color: root.isNightMode ? "#ffffff" : "#1a1824"
                font.pixelSize: root.width * 0.185
                font.bold: true
                opacity: root.acOn ? 0.0 : 1.0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "°C"
            color: root.dialColor
            font.pixelSize: root.width * 0.092
            opacity: root.acOn ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    // -- Interaction: left (or right when flipped) semicircle = temperature slider --
    MouseArea {
        anchors.fill: parent
        enabled: !root.disabled

        function tempAt(mx, my) {
            var ex = root.flipArc ? (root.width - mx) : mx;
            var dx = ex - root.width  / 2;
            var dy = my - root.height / 2;
            var a  = Math.atan2(dy, dx);

            var progress;
            if (a >= Math.PI / 2) {
                progress = (a - Math.PI / 2) / Math.PI;
            } else if (a < -Math.PI / 2) {
                progress = (a + 3 * Math.PI / 2) / Math.PI;
            } else {
                return -1;
            }

            return root.minTemp + Math.max(0, Math.min(1, progress)) * (root.maxTemp - root.minTemp);
        }

        onPressed: function(mouse) {
            root._dragging = true;
            var t = tempAt(mouse.x, mouse.y);
            if (t >= 0) root.temperature = Math.round(t * 2) / 2;
        }
        onPositionChanged: function(mouse) {
            var t = tempAt(mouse.x, mouse.y);
            if (t >= 0) root.temperature = Math.round(t * 2) / 2;
        }
        onReleased: root._dragging = false
    }
}
