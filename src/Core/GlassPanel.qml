import QtQuick
import QtQuick.Effects

Item {
    id: root
    property color colorSurface: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceAlt : "#dd141021"
    property color colorStroke: typeof mainRoot !== "undefined" ? mainRoot.colorStroke : "#2bffffff"
    property int radiusSize: 16
    default property alias content: container.data

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.radiusSize
        color: root.colorSurface
        border.color: root.colorStroke
        border.width: 1
        visible: false
    }

    MultiEffect {
        source: bg
        anchors.fill: bg
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.2
        shadowBlur: 15
        shadowVerticalOffset: 5
    }

    Item {
        id: container
        anchors.fill: parent
        anchors.margins: 16
    }
}
