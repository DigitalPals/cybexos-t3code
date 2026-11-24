pragma Singleton
import QtQuick
import Quickshell

// The allow-list of product marks this plugin bundles: T3 itself and the
// providers a thread can run on. Trimmed from Cybex OS's Common/BrandIcons.qml.
// Keeping file names behind this list stops provider data from becoming an
// arbitrary asset path. Provenance: assets/README.md.
Singleton {
    id: root

    readonly property var names: ["claude", "kimi", "openai", "t3"]
    readonly property var files: ({
        claude: "claude.svg",
        kimi: "kimi.svg",
        openai: "openai.svg",
        t3: "t3.svg"
    })
    // Hover marks are paint variants with identical geometry.
    readonly property var highlightFiles: ({
        claude: "claude-white.svg",
        kimi: "kimi-white.svg",
        openai: "openai-white.svg",
        // The canonical T3 wordmark is already white.
        t3: "t3.svg"
    })
    readonly property var labels: ({
        claude: "Claude",
        kimi: "Kimi",
        openai: "OpenAI",
        t3: "T3 Code"
    })

    function key(value) {
        return String(value ?? "").trim().toLowerCase();
    }

    function has(value) {
        return names.indexOf(key(value)) >= 0;
    }

    function source(value) {
        const name = key(value);
        return has(name) ? Qt.resolvedUrl("../assets/" + files[name]) : "";
    }

    function highlightSource(value) {
        const name = key(value);
        return has(name) ? Qt.resolvedUrl("../assets/" + highlightFiles[name]) : "";
    }

    function label(value) {
        const name = key(value);
        return has(name) ? labels[name] : "";
    }
}
