pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import "Launch.js" as Launch

// What the T3 Code singletons need from the shell that hosts them.
//
// The built-in widget read the shell's private Settings, Popouts, Notifs,
// NetworkStatus and Activity singletons. A plugin cannot, so the plugin's
// own entry points report here instead:
//
// - Service.qml attaches while the plugin is enabled. The connection only
//   runs while something is attached, so disabling the plugin closes the
//   link even though these singletons outlive it in the shell's engine.
// - Each bar widget registers itself, reports whether its panel is open,
//   and receives open/close requests (IPC, the sign-in helper, a thread
//   action that closes the panel).
Singleton {
    id: root

    // ---- lifetime ---------------------------------------------------------
    property int attachments: 0
    readonly property bool active: attachments > 0

    function attach() {
        attachments += 1;
    }

    function detach() {
        attachments = Math.max(0, attachments - 1);
    }

    // ---- package ---------------------------------------------------------
    // scripts/t3-cloud.mjs, beside this directory in the loaded package.
    readonly property string helperScript:
        Launch.localPath(Qt.resolvedUrl("../scripts/t3-cloud.mjs"))

    // Exit status and message of the launcher when Node.js is not installed.
    readonly property int nodeMissingExit: Launch.NODE_MISSING_EXIT
    readonly property string nodeMissingMessage: Launch.NODE_MISSING_MESSAGE

    // Run the sign-in/ticket helper with Node; see Launch.js.
    function helperCommand(subcommand) {
        return Launch.helperCommand(helperScript, subcommand);
    }

    // ---- bar widgets and panel ---------------------------------------------
    property var widgets: []
    property bool panelOpen: false
    // The bar's text ink and size, from the widget's bar facade.
    property string barForeground: ""
    property int barSize: 0
    property bool reducedMotion: false
    // Focus rings follow keyboard use, as in the shell.
    property bool keyboardModality: false

    function registerWidget(widget) {
        if (widgets.indexOf(widget) < 0)
            widgets = widgets.concat([widget]);
    }

    function unregisterWidget(widget) {
        widgets = widgets.filter(item => item !== widget);
        refreshPanelOpen();
    }

    function refreshPanelOpen() {
        panelOpen = widgets.some(item => item && item.opened === true);
    }

    function openPanel() {
        const shown = widgets.filter(item => item && item.visible);
        const target = shown.length > 0 ? shown[0] : widgets[0];
        if (!target)
            return false;
        target.open();
        return true;
    }

    function closePanel() {
        for (const widget of widgets) {
            if (widget && widget.opened)
                widget.close();
        }
    }

    function togglePanel() {
        if (panelOpen)
            closePanel();
        else
            openPanel();
    }

    // ---- idle --------------------------------------------------------------
    // Nobody at the machine: automatic reconnects wait, and `resumed` retries
    // at once. Respects idle inhibitors, like the shell's own monitor.
    readonly property bool idle: idleMonitor.isIdle
    signal resumed()

    IdleMonitor {
        id: idleMonitor
        enabled: Qt.platform.pluginName.startsWith("wayland")
        timeout: 300
        respectInhibitors: true
        onIsIdleChanged: {
            if (!isIdle)
                root.resumed();
        }
    }

    // ---- notifications -----------------------------------------------------
    // The host puts omarchy-notification-send on the shell's PATH.
    function notify(notification) {
        const summary = String(notification.summary || "");
        if (summary === "")
            return;
        Quickshell.execDetached(["omarchy-notification-send",
            "--app-name", String(notification.appName || "T3 Code"),
            "-u", "normal", "-i", String(notification.appIcon || "utilities-terminal"),
            summary, String(notification.body || "")]);
    }
}
