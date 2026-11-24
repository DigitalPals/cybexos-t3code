import QtQuick
import Quickshell
import Quickshell.Io
import "Core"

// The plugin's one shared service, alive exactly while the plugin is enabled.
// Attaching to T3Host starts the T3 Code connection; disabling the plugin
// destroys this object, which closes it. It also owns the IPC target, so a
// second monitor's widget does not register the same target twice:
//
//   qs ipc call digitalpals.t3code toggle   (or open, close)
Scope {
    id: root

    Component.onCompleted: T3Host.attach()
    Component.onDestruction: T3Host.detach()

    IpcHandler {
        target: "digitalpals.t3code"

        function open(): void { T3Host.openPanel(); }
        function close(): void { T3Host.closePanel(); }
        function toggle(): void { T3Host.togglePanel(); }
        function show(): void { T3Host.openPanel(); }
        function hide(): void { T3Host.closePanel(); }
    }
}
