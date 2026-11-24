pragma ComponentBehavior: Bound
import QtQuick
import qs.Ui as Ui
import "Core"
import "Panel"

// T3 Code in the menubar: the status chip, and the T3 panel hanging from it.
// The host injects `bar` (its bar facade), `moduleName` and `settings`.
Ui.Panel {
    id: root

    moduleName: "digitalpals.t3code"
    // Service.qml owns the IPC target, once for every monitor.
    manageIpc: false

    readonly property bool showLabel: setting("showLabel", true) !== false
    readonly property bool vertical: bar ? bar.vertical === true : false
    // The host gives the widget a fixed slot (`--width`, 120 by default).
    // Rather than clip the word, the chip drops it when it does not fit.
    readonly property bool labelFits: chip.compactWidth + chip.detailSaving <= width
    property alias popover: popoverLoader.item
    // Read-only state for diagnostics and the real-engine test.
    readonly property string connectionState: T3Code.state
    readonly property string chipLabel: chip.label
    readonly property var host: T3Host
    readonly property Item panelCard: keys.parent ? keys.parent.parent : null

    implicitWidth: chip.implicitWidth
    implicitHeight: chip.implicitHeight

    Component.onCompleted: {
        T3Host.registerWidget(root);
        syncBar();
    }
    Component.onDestruction: T3Host.unregisterWidget(root)
    onOpenedChanged: T3Host.refreshPanelOpen()
    onBarChanged: syncBar()

    function syncBar() {
        if (!bar)
            return;
        T3Host.barForeground = String(bar.foreground);
        T3Host.barSize = Number(bar.barSize) || 0;
        T3Host.reducedMotion = bar.foregroundAnimationEnabled === false;
    }

    Connections {
        target: root.bar
        ignoreUnknownSignals: true

        function onForegroundChanged() { root.syncBar(); }
        function onBarSizeChanged() { root.syncBar(); }
        function onForegroundAnimationEnabledChanged() { root.syncBar(); }
    }

    T3Chip {
        id: chip
        bar: root.bar
        anchors.centerIn: parent
        displayMode: root.showLabel && !root.vertical && root.labelFits ? 2 : 0
        held: root.opened
        onClicked: root.toggle()
    }

    Ui.KeyboardPanel {
        id: panel

        readonly property real borderInset: panel.verticalContentInset - panel.padding * 2

        anchorItem: chip
        owner: root
        bar: root.bar
        open: root.opened
        padding: 0
        focusTarget: keys
        contentWidth: panel.fittedContentWidth(Math.max(1,
            popoverLoader.item ? popoverLoader.item.implicitWidth + panel.borderInset : 1))
        contentHeight: panel.fittedContentHeight(
            popoverLoader.item ? popoverLoader.item.implicitHeight : 1)

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true

            // Focus rings follow keyboard use: a navigation key turns them on,
            // a pointer press off.
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => {
                if ([Qt.Key_Tab, Qt.Key_Backtab, Qt.Key_Up, Qt.Key_Down,
                        Qt.Key_Left, Qt.Key_Right].includes(event.key))
                    T3Host.keyboardModality = true;
                event.accepted = false;
            }
            // Escape goes back a page or closes a layer first; on the inbox
            // it closes the panel.
            Keys.onEscapePressed: event => {
                const item = popoverLoader.item;
                if (!item || !item.handleEscape())
                    root.close();
                event.accepted = true;
            }

            PointHandler {
                onActiveChanged: if (active) T3Host.keyboardModality = false
            }

            // Rebuilt on every open, like the built-in panel; drafts and
            // selections live in the singletons.
            Loader {
                id: popoverLoader
                anchors.fill: parent
                active: root.opened || panel.visible
                focus: true
                sourceComponent: T3CodePopover {
                    availableWidth: panel.availableCardWidth - panel.borderInset
                    availableHeight: panel.availableCardHeight - panel.verticalContentInset
                    focus: true
                }
            }
        }
    }
}
