import QtQuick
import "../Core"

// A menubar chip: content in a row, a hover/held fill, a press shrink and a
// tooltip through the bar facade. Trimmed from Cybex OS's Bar/BarChip.qml;
// the shell's hover-to-switch popouts and drag ordering are host features a
// plugin cannot reach, so a click toggles the panel through `clicked`.
Rectangle {
    id: root

    default property alias content: content.data

    // The bar facade the host injected into the widget (may be null).
    property var bar: null
    property string shape: "pill"
    readonly property bool inner: shape === "inner"
    property real pillHeight: inner ? Theme.chipInnerHeight : Theme.chipHeight
    property real hPadding: 7
    property real spacing: 5
    property real leftPadding: hPadding
    property real rightPadding: hPadding
    property color restFill: "transparent"
    property color hoverFill: Theme.barChipHover
    property bool held: false
    property bool pressFeedback: true
    property string tooltip: ""
    property int tooltipAlign: 0

    readonly property bool hovered: mouse.containsMouse

    signal clicked()
    signal middleClicked()

    readonly property real naturalWidth: content.implicitWidth + leftPadding + rightPadding

    implicitHeight: pillHeight
    implicitWidth: naturalWidth
    radius: Theme.chipRadius
    color: held || hovered ? hoverFill : restFill
    scale: pressFeedback && mouse.pressed && !Theme.reducedMotion ? 0.96 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Theme.pressDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.springCurve
        }
    }

    Behavior on color {
        ColorAnimation { duration: Theme.chipFadeDuration }
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.expandDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.springCurve
        }
    }

    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        x: root.leftPadding
        spacing: root.spacing
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                root.middleClicked();
            else
                root.clicked();
        }
        onContainsMouseChanged: {
            if (!root.bar)
                return;
            if (containsMouse && root.tooltip !== "" && !root.held)
                root.bar.showTooltip(root, root.tooltip);
            else
                root.bar.hideTooltip(root);
        }
    }

    onHeldChanged: if (held && bar) bar.hideTooltip(root)
    onTooltipChanged: {
        if (bar && mouse.containsMouse && !held)
            bar.showTooltip(root, tooltip);
    }
}
