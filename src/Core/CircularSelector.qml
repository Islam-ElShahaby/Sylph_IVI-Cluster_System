import QtQuick
import QtQuick.Controls

Item {
    id: root
    width: 320
    height: 60

    // Properties
    property var items: ["Any", "Eco", "Comfort", "Sport"]
    property int currentIndex: 0
    property int transitionDistance: 40
    property int transitionDuration: 300
    property bool isNightMode: typeof mainRoot !== "undefined" ? mainRoot.isNightMode : true
    property color textColor: typeof mainRoot !== "undefined" ? mainRoot.colorTextPrimary : "#FFFFFF"
    property color accentColor: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"

    // Subtle glass container
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        gradient: Gradient {
            GradientStop { 
                position: 0.0 
                color: root.isNightMode ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.04) 
            }
            GradientStop { 
                position: 1.0 
                color: root.isNightMode ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.02) 
            }
        }
        border.color: root.isNightMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.08)
    }

    // Left Arrow Button
    AbstractButton {
        id: leftBtn
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: height

        contentItem: Text {
            text: "<"
            font.pixelSize: root.height * 0.4
            font.weight: Font.Bold
            color: leftBtn.pressed ? root.accentColor : root.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        onClicked: {
            if (animGroup.running || root.items.length <= 1)
                return;
            // Circular wrap backwards
            let nextIndex = (root.currentIndex - 1 + root.items.length) % root.items.length;
            animateTransition(nextIndex, -1); // -1 = Move Left
        }
    }

    // Right Arrow Button
    AbstractButton {
        id: rightBtn
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: height

        contentItem: Text {
            text: ">"
            font.pixelSize: root.height * 0.4
            font.weight: Font.Bold
            color: rightBtn.pressed ? root.accentColor : root.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        onClicked: {
            if (animGroup.running || root.items.length <= 1)
                return;
            // Circular wrap forwards
            let nextIndex = (root.currentIndex + 1) % root.items.length;
            animateTransition(nextIndex, 1); // 1 = Move Right
        }
    }

    // Clipping container for the text to ensure it doesn't spill over the buttons
    Item {
        id: textContainer
        anchors.left: leftBtn.right
        anchors.right: rightBtn.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true

        // The text sliding out
        Text {
            id: outgoingText
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: root.height * 0.4
            font.weight: Font.Medium
            color: root.textColor
            opacity: 0
            // Initial positioning breaks anchors to allow manual X animation
        }

        // The text sliding in / currently displayed
        Text {
            id: incomingText
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: root.height * 0.4
            font.weight: Font.Medium
            color: root.textColor
            text: (root.items && root.items.length > root.currentIndex) ? root.items[root.currentIndex] : ""
            // Center horizontally based on its implicit width
            x: (parent.width - width) / 2
        }
    }

    // Animation Controller
    ParallelAnimation {
        id: animGroup
        property int direction: 1 // 1 for right, -1 for left

        // 1. Move old text out
        NumberAnimation {
            target: outgoingText
            property: "x"
            // Move from center to the offset distance
            to: ((textContainer.width - outgoingText.width) / 2) + (animGroup.direction * root.transitionDistance)
            duration: root.transitionDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: outgoingText
            property: "opacity"
            to: 0
            duration: root.transitionDuration
        }

        // 2. Move new text in
        NumberAnimation {
            target: incomingText
            property: "x"
            // Start from opposite offset distance...
            from: ((textContainer.width - incomingText.width) / 2) - (animGroup.direction * root.transitionDistance)
            // ...and settle in the exact center
            to: (textContainer.width - incomingText.width) / 2
            duration: root.transitionDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: incomingText
            property: "opacity"
            from: 0
            to: 1
            duration: root.transitionDuration
        }
    }

    // Logic Function
    function animateTransition(nextIndex, direction) {
        // Lock the outgoing text to whatever the incoming text currently is
        outgoingText.text = incomingText.text;
        outgoingText.x = incomingText.x;
        outgoingText.opacity = 1;

        // Update the state for the new incoming text
        root.currentIndex = nextIndex;
        incomingText.text = root.items[root.currentIndex];

        // Apply direction and trigger the animations
        animGroup.direction = direction;
        animGroup.start();
    }
}
