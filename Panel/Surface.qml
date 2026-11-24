pragma ComponentBehavior: Bound
import QtQuick
import "../Core"

// Shared popover surface: semantic width, the bar's own corner, a hairline
// border and a comfortable inner gutter. A panel sits on the shell's deepest
// surface rather than on a lighter card stacked over it — everything inside is
// separated by hairlines and space instead.
//
// The plugin's popup card paints the surface itself, so what this contributes
// is the layout and the padding. Trimmed from Cybex OS's Popovers/Surface.qml.
PopoutPanel {
    id: root

    property int padding: Theme.panelPadding
    property alias spacing: column.spacing
    default property alias content: column.data

    implicitWidth: availableWidth > 0
        ? Math.min(Theme.popWidth, availableWidth) : Theme.popWidth
    implicitHeight: column.implicitHeight + padding * 2

    Rectangle {
        id: bg
        visible: root.drawBackground
        anchors.fill: parent
        radius: Theme.panelRadius
        color: root.surfaceColor
        border.width: Theme.surfaceBorderWidth
        border.color: root.surfaceBorderColor

        Behavior on color {
            ColorAnimation { duration: Theme.surfaceDuration }
        }
    }

    Column {
        id: column
        x: root.padding
        y: root.padding
        width: Math.max(0, parent.width - root.padding * 2)
        spacing: Theme.panelSectionSpacing
    }
}
