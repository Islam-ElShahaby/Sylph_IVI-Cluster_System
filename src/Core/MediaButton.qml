import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Button {
    id: control
    property color fillColor: typeof mainRoot !== "undefined" ? mainRoot.colorSurfaceAlt : "#dd141021"
    property color textColor: typeof mainRoot !== "undefined" ? mainRoot.colorTextPrimary : "#ffffff"
    property color colorAccent: typeof mainRoot !== "undefined" ? mainRoot.colorAccent : "#c0b3ff"
    property color colorStroke: typeof mainRoot !== "undefined" ? mainRoot.colorStroke : "#2bffffff"
    property int size: 64
    property int textSize: 18
    property int iconSize: 24
    
    // New property for icon
    property string iconSource: ""
    
    width: size
    height: size
    
    implicitWidth: size
    implicitHeight: size
    
    background: Rectangle {
        radius: width / 2
        color: control.down ? control.colorAccent : control.fillColor
        border.color: control.colorStroke
        border.width: 1
    }
    
    contentItem: Item {
        anchors.fill: parent
        
        // Show text if iconSource is empty
        Text {
            visible: control.iconSource === ""
            text: control.text
            color: control.down ? "#c80e0a17" : control.textColor
            font.pixelSize: control.textSize
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            anchors.fill: parent
        }
        
        // Show icon if iconSource is set
        Item {
            visible: control.iconSource !== ""
            anchors.centerIn: parent
            width: control.iconSize
            height: control.iconSize
            
            Image {
                id: svgImg
                source: control.iconSource
                anchors.fill: parent
                sourceSize.width: 64
                sourceSize.height: 64
                mipmap: true
                fillMode: Image.PreserveAspectFit
                visible: false
            }
            
            MultiEffect {
                source: svgImg
                anchors.fill: parent
                colorization: 1.0
                brightness: 1.0
                colorizationColor: control.down ? "#c80e0a17" : control.textColor
            }
        }
    }
}
