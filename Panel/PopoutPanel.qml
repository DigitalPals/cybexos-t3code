import QtQuick
import "../Core"

// The contract between the T3 panel and the popup that hosts it, from Cybex
// OS's Popovers/PopoutPanel.qml: the usable envelope, and Escape handling.
FocusScope {
    id: root

    property color surfaceColor: "transparent"
    property color surfaceBorderColor: "transparent"
    // The host's popup card paints the surface, so panels draw none.
    property bool drawBackground: false

    // The usable envelope of the output the popup is drawn on.
    property real availableWidth: 0
    property real availableHeight: 0

    // Escape inside a panel. Return true if the panel consumed it, false to
    // let the host dismiss the popup.
    function handleEscape(): bool {
        return false;
    }
}
