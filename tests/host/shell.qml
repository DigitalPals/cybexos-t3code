pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "Common"
import "Bar"
import "Popovers"

// Real-engine check for the T3 Code plugin, run by tests/host/real-engine.py
// inside a disposable copy of a Cybex OS shell tree. The plugin is installed
// and enabled like any user package; this shell draws the stock UserWidgets
// plugin areas on every output and walks the widget through its life.
ShellRoot {
    id: root

    readonly property string pluginId: "digitalpals.t3code"
    readonly property string outDir: Quickshell.env("T3_PLUGIN_TEST_OUT")
    property int ticks: 0
    property int stage: 0
    property bool finished: false
    property var savedHost: null
    property var savedService: null
    property Item firstBar: null
    property int readyTick: 0

    function done(ok, detail) {
        if (finished)
            return;
        finished = true;
        console.warn("T3_PLUGIN_RESULT " + (ok ? "pass " : "fail ") + detail);
        Quickshell.execDetached(["bash", "-c", 'sleep 0.3; kill -TERM -- "$1"', "bash",
            String(Quickshell.processId)]);
    }

    function check(value, detail) {
        if (!value)
            done(false, detail);
        return !!value;
    }

    function widgets() {
        return UserPlugins.widgetHosts.filter(h => h.descriptor.id === root.pluginId && h.ready)
            .map(h => h.widget);
    }

    function cli(args) {
        UserPlugins.enqueue(["python3", UserPlugins.helper].concat(args));
    }

    function grab(item, name) {
        if (outDir !== "")
            item.grabToImage(result => result.saveToFile(outDir + "/" + name));
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: screenBar
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 36
            color: "transparent"

            Rectangle {
                id: barContent
                anchors.fill: parent
                color: Theme.barSurface
                Component.onCompleted: if (!root.firstBar) root.firstBar = barContent

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    UserWidgets {
                        section: "right"
                        screenName: screenBar.modelData.name
                        availableWidth: 640
                    }
                }
            }
        }
    }

    // The built-in panel, for a before/after comparison screenshot. Its
    // module is off in this home, so it never connects either.
    FloatingWindow {
        visible: true
        implicitWidth: 560
        implicitHeight: 420
        color: Theme.barSurface

        T3CodePopover {
            id: builtinPopover
            width: implicitWidth
        }
    }

    Process {
        id: ipc
        property string expect: ""
        command: [Quickshell.env("OMARCHY_PATH") + "/bin/omarchy-shell", root.pluginId, "toggle"]
    }

    Timer {
        interval: 100
        repeat: true
        running: !root.finished
        onTriggered: {
            if (++root.ticks > 300) {
                root.done(false, "timeout at stage " + root.stage + " errors="
                    + JSON.stringify(OmarchyPlugins.errors) + " " + UserPlugins.error
                    + " hosts=" + JSON.stringify(UserPlugins.widgetHosts
                        .filter(h => h.descriptor.id === root.pluginId)
                        .map(h => ({ ready: h.ready, error: h.error }))));
                return;
            }
            const list = root.widgets();
            if (root.stage === 0) {
                const service = OmarchyPlugins.serviceFor(root.pluginId);
                if (!service || list.length !== Quickshell.screens.length)
                    return;
                const widget = list[0];
                if (!root.check(Object.keys(OmarchyPlugins.errors).length === 0,
                        "plugin errors " + JSON.stringify(OmarchyPlugins.errors)))
                    return;
                // Service and widgets must share one set of singletons.
                if (!root.check(widget.host.active && list.every(w => w.host === widget.host),
                        "service and widgets do not share T3Host"))
                    return;
                // Nothing is signed in inside the disposable home.
                if (widget.connectionState !== "signed-out" || widget.chipLabel !== "sign in")
                    return;
                if (!root.check(widget.width > 0 && widget.height > 0
                        && widget.implicitWidth > 0, "widget has no size"))
                    return;
                root.savedHost = widget.host;
                root.savedService = service;
                // Let images and fonts settle before the screenshots.
                if (root.readyTick === 0)
                    root.readyTick = root.ticks;
                if (root.ticks - root.readyTick < 10)
                    return;
                root.grab(root.firstBar, "after-bar.png");
                root.grab(builtinPopover, "before-panel-builtin.png");
                widget.open();
                root.stage = 1;
            } else if (root.stage === 1) {
                const widget = list[0];
                const popover = widget.popover;
                if (!widget.opened || !popover || popover.implicitHeight <= 0)
                    return;
                if (!root.check(popover.page === "inbox", "panel did not open on the inbox"))
                    return;
                if (!root.check(root.savedHost.panelOpen, "T3Host did not see the open panel"))
                    return;
                root.stage = 2;
                root.ticks = Math.min(root.ticks, 250);
            } else if (root.stage === 2) {
                // Give the fade-in a moment, then capture the panel.
                if (root.ticks % 5 !== 0)
                    return;
                root.grab(list[0].panelCard, "after-panel.png");
                ipc.running = true;
                root.stage = 3;
            } else if (root.stage === 3) {
                // The IPC toggle (through the host's omarchy-shell) closes it.
                if (list[0].opened || ipc.running)
                    return;
                root.cli(["disable", root.pluginId]);
                root.stage = 4;
            } else if (root.stage === 4) {
                if (OmarchyPlugins.serviceFor(root.pluginId) || list.length > 0)
                    return;
                if (!root.check(!root.savedHost.active,
                        "the connection gate stayed open after disable"))
                    return;
                root.done(true, "service + widget on " + Quickshell.screens.length
                    + " outputs, shared singletons, signed-out chip, panel, IPC toggle, disable");
            }
        }
    }
}
