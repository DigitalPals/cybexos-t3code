import QtQuick
import "../Core"

// A product mark drawn in the menubar's monochrome ink, brightening on hover.
// Trimmed from Cybex OS's Bar/BarBrandIcon.qml.
Item {
    id: root

    property string name: ""
    property bool highlighted: false

    implicitWidth: Theme.iconMedium
    implicitHeight: Theme.iconMedium
    Accessible.ignored: true

    BrandIcon {
        anchors.fill: parent
        name: root.name
        highlighted: root.highlighted
        colorized: true
        tint: Theme.barIcon
        normalizeTintSource: true
    }
}
