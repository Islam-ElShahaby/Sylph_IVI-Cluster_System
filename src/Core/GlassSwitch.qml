import QtQuick
import QtQuick.Controls

Item {
    id: control
    implicitWidth: 46
    implicitHeight: 24

    property bool checked: false
    property bool enabled: true
    property bool isNightMode: typeof mainRoot !== "undefined" ? mainRoot.isNightMode : true
    property color checkedColor: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff" // Beautiful premium highlight
    property color uncheckedColor: isNightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.08) : Qt.rgba(0.0, 0.0, 0.0, 0.08) // Frost track
    property color knobColor: "#ffffff"
    property color borderColor: isNightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.15) : Qt.rgba(0.0, 0.0, 0.0, 0.12)

    signal toggled(bool isChecked)

    opacity: enabled ? 1.0 : 0.4
    Behavior on opacity { OpacityAnimator { duration: 150 } }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: control.checked ? control.checkedColor : control.uncheckedColor
        border.color: control.checked ? Qt.rgba(1, 1, 1, 0.1) : control.borderColor
        border.width: 1

        Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.InOutQuad } }

        Rectangle {
            id: knob
            width: parent.height - 6
            height: parent.height - 6
            radius: height / 2
            color: control.knobColor
            anchors.verticalCenter: parent.verticalCenter
            x: control.checked ? parent.width - width - 3 : 3

            Behavior on x {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: control.enabled
        cursorShape: Qt.PointingHandCursor
        // Controlled component: don't flip our own state (that would break the
        // parent's `checked:` binding and let the switch lie when the action
        // fails, e.g. Bluetooth blocked by rfkill). Emit and let the bound
        // source drive `checked` to reflect the real state.
        onClicked: control.toggled(!control.checked)
    }
}
