// How the plugin starts scripts/t3-cloud.mjs. Pure, so Node tests run it.
//
// The helper needs Node.js. Rather than let a missing `node` surface as a
// bare "did not complete", the launcher checks for it first and exits with
// NODE_MISSING_EXIT and a sentence saying what to install.

var NODE_MISSING_EXIT = 127;
var NODE_MISSING_MESSAGE =
    "T3 Code needs Node.js: install it so `node` is on PATH, then try again.";

function helperCommand(script, subcommand) {
    return ["sh", "-c",
        "command -v node >/dev/null 2>&1 || { printf '%s\\n' \"$2\" >&2; exit "
            + NODE_MISSING_EXIT + "; }; exec node \"$0\" \"$1\"",
        String(script), String(subcommand), NODE_MISSING_MESSAGE];
}

// A desktop notification. The Cybex OS shell puts its Omarchy helper,
// omarchy-notification-send, on the PATH of what it starts; notify-send is
// the fallback. Arguments are passed positionally, never through the shell
// text, so a thread title cannot become a command.
function notifyCommand(appName, icon, summary, body) {
    return ["sh", "-c",
        "if command -v omarchy-notification-send >/dev/null 2>&1; then "
            + "exec omarchy-notification-send --app-name \"$1\" -u normal -i \"$2\" \"$3\" \"$4\"; "
            + "elif command -v notify-send >/dev/null 2>&1; then "
            + "exec notify-send -a \"$1\" -i \"$2\" -- \"$3\" \"$4\"; fi",
        "t3-notify", String(appName), String(icon), String(summary), String(body)];
}

// A file:// URL from Qt.resolvedUrl as a local path.
function localPath(url) {
    var value = String(url);
    return value.indexOf("file://") === 0 ? decodeURIComponent(value.slice(7)) : value;
}

var exported = {
    NODE_MISSING_EXIT: NODE_MISSING_EXIT,
    NODE_MISSING_MESSAGE: NODE_MISSING_MESSAGE,
    helperCommand: helperCommand,
    notifyCommand: notifyCommand,
    localPath: localPath
};

if (typeof module !== "undefined" && module.exports)
    module.exports = exported;
