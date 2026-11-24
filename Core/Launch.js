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

// A file:// URL from Qt.resolvedUrl as a local path.
function localPath(url) {
    var value = String(url);
    return value.indexOf("file://") === 0 ? decodeURIComponent(value.slice(7)) : value;
}

var exported = {
    NODE_MISSING_EXIT: NODE_MISSING_EXIT,
    NODE_MISSING_MESSAGE: NODE_MISSING_MESSAGE,
    helperCommand: helperCommand,
    localPath: localPath
};

if (typeof module !== "undefined" && module.exports)
    module.exports = exported;
