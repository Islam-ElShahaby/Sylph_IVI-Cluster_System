import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root

    // -- Public API --
    // Provide card titles - must match the number of children placed inside `cardContainer`
    property var cardTitles: []
    property int currentIndex: 0
    property int transitionDuration: 350

    // Theme tokens (inherit from parent or override)
    property int radiusLarge: typeof mainRoot !== "undefined" ? mainRoot.radiusLarge : 28
    property color colorSurface: typeof mainRoot !== "undefined" ? mainRoot.colorSurface : "#c80e0a17"
    property color colorStroke: typeof mainRoot !== "undefined" ? mainRoot.colorStroke : "#2bffffff"
    property color colorTextPrimary: typeof mainRoot !== "undefined" ? mainRoot.colorTextPrimary : "#ffffff"
    property color colorTextSubtle: typeof mainRoot !== "undefined" ? mainRoot.colorTextSubtle : "#b8b2c8"
    property color colorAccent: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"

    // -- Private --
    default property alias cards: cardContainer.children
    readonly property int cardCount: cardContainer.children.length

    // -- Glassmorphism card background --
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
        blurMultiplier: 1.0
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.4
        shadowBlur: 20
        shadowVerticalOffset: 10
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 0

        // -- Title bar with arrows --
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 16
            spacing: 8

            // Left arrow
            AbstractButton {
                id: leftBtn
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                enabled: root.cardCount > 1
                visible: root.cardCount > 1

                contentItem: Text {
                    text: "‹"
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    color: leftBtn.pressed ? root.colorAccent
                         : leftBtn.hovered ? root.colorTextPrimary
                         : root.colorTextSubtle
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                background: Rectangle {
                    radius: 8
                    color: leftBtn.pressed  ? Qt.rgba(1,1,1,0.08)
                         : leftBtn.hovered  ? Qt.rgba(1,1,1,0.05)
                         : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                onClicked: {
                    if (fadeOut.running || fadeIn.running) return
                    let next = (root.currentIndex - 1 + root.cardCount) % root.cardCount
                    switchTo(next)
                }
            }

            // Animated title
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                clip: true

                Text {
                    id: outgoingTitle
                    anchors.verticalCenter: parent.verticalCenter
                    x: (parent.width - width) / 2
                    font.pixelSize: 18
                    font.bold: true
                    color: root.colorTextPrimary
                    opacity: 0
                }

                Text {
                    id: incomingTitle
                    anchors.verticalCenter: parent.verticalCenter
                    x: (parent.width - width) / 2
                    font.pixelSize: 18
                    font.bold: true
                    color: root.colorTextPrimary
                    text: root.cardTitles.length > root.currentIndex ? root.cardTitles[root.currentIndex] : ""
                }
            }

            // Page dots
            Row {
                spacing: 6
                visible: root.cardCount > 1
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: root.cardCount
                    Rectangle {
                        width: index === root.currentIndex ? 18 : 6
                        height: 6
                        radius: 3
                        color: index === root.currentIndex ? root.colorAccent : root.colorStroke
                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }

            // Right arrow
            AbstractButton {
                id: rightBtn
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                enabled: root.cardCount > 1
                visible: root.cardCount > 1

                contentItem: Text {
                    text: "›"
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    color: rightBtn.pressed ? root.colorAccent
                         : rightBtn.hovered ? root.colorTextPrimary
                         : root.colorTextSubtle
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                background: Rectangle {
                    radius: 8
                    color: rightBtn.pressed  ? Qt.rgba(1,1,1,0.08)
                         : rightBtn.hovered  ? Qt.rgba(1,1,1,0.05)
                         : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                onClicked: {
                    if (fadeOut.running || fadeIn.running) return
                    let next = (root.currentIndex + 1) % root.cardCount
                    switchTo(next)
                }
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.colorStroke
            opacity: 0.6
        }

        // -- Card stack --
        Item {
            id: cardContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 16
        }
    }

    // -- Fade animations --
    property int _nextIndex: 0
    property int _direction: 1

    NumberAnimation {
        id: fadeOut
        target: cardContainer.children[root.currentIndex] || null
        property: "opacity"
        from: 1; to: 0
        duration: root.transitionDuration / 2
        easing.type: Easing.InQuad

        onFinished: {
            // Hide old card, show and fade in new one
            if (cardContainer.children[root.currentIndex]) {
                cardContainer.children[root.currentIndex].visible = false
                cardContainer.children[root.currentIndex].enabled = false
            }

            root.currentIndex = root._nextIndex

            if (cardContainer.children[root.currentIndex]) {
                cardContainer.children[root.currentIndex].visible = true
                cardContainer.children[root.currentIndex].enabled = true
                cardContainer.children[root.currentIndex].opacity = 0
            }

            // Update title text
            incomingTitle.text = root.cardTitles.length > root.currentIndex ? root.cardTitles[root.currentIndex] : ""

            fadeIn.start()
            titleFadeIn.start()
        }
    }

    NumberAnimation {
        id: fadeIn
        target: cardContainer.children[root.currentIndex] || null
        property: "opacity"
        from: 0; to: 1
        duration: root.transitionDuration / 2
        easing.type: Easing.OutQuad
    }

    // Title animations
    ParallelAnimation {
        id: titleFadeOut
        NumberAnimation {
            target: outgoingTitle; property: "opacity"
            from: 1; to: 0; duration: root.transitionDuration / 2
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: outgoingTitle; property: "x"
            to: ((outgoingTitle.parent ? outgoingTitle.parent.width : 0) - outgoingTitle.width) / 2 + (root._direction * 30)
            duration: root.transitionDuration / 2
            easing.type: Easing.InQuad
        }
    }

    ParallelAnimation {
        id: titleFadeIn
        NumberAnimation {
            target: incomingTitle; property: "opacity"
            from: 0; to: 1; duration: root.transitionDuration / 2
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: incomingTitle; property: "x"
            from: ((incomingTitle.parent ? incomingTitle.parent.width : 0) - incomingTitle.width) / 2 - (root._direction * 30)
            to: ((incomingTitle.parent ? incomingTitle.parent.width : 0) - incomingTitle.width) / 2
            duration: root.transitionDuration / 2
            easing.type: Easing.OutQuad
        }
    }

    // -- Switch logic --
    function switchTo(nextIndex) {
        if (nextIndex === root.currentIndex) return
        root._direction = nextIndex > root.currentIndex ? 1 : -1
        root._nextIndex = nextIndex

        if (cardContainer.children[root.currentIndex]) {
            cardContainer.children[root.currentIndex].enabled = false
        }

        // Start title outgoing
        outgoingTitle.text = incomingTitle.text
        outgoingTitle.x = incomingTitle.x
        outgoingTitle.opacity = 1
        incomingTitle.opacity = 0
        titleFadeOut.start()

        // Start card fade
        fadeOut.target = cardContainer.children[root.currentIndex]
        fadeOut.start()
    }

    // -- Initial setup --
    Component.onCompleted: {
        for (let i = 0; i < cardContainer.children.length; i++) {
            let child = cardContainer.children[i]
            child.anchors.fill = cardContainer
            child.visible = (i === currentIndex)
            child.enabled = (i === currentIndex)
            child.opacity = (i === currentIndex) ? 1 : 0
        }
    }
}
