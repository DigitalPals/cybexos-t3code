// Locates the plugin's sources for the tests in this directory. Ported from
// Cybex OS's tests/quickshell/shell.cjs: the shell's Common/ is this
// package's Core/, its Popovers/ and Bar/ chip are Panel/.
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const executable = name => execFileSync("sh", ["-c", "command -v " + name], { encoding: "utf8" }).trim();

const shellDir = path.resolve(__dirname, "..");

// require() a pure-JS helper out of Core/ by name.
function load(name) {
    return require(path.join(shellDir, "Core", name));
}

// QML source as its English text reads: I18n.tr("Text") becomes "Text".
function untranslated(source) {
    return String(source).replace(/I18n\.tr\(("(?:[^"\\]|\\.)*")\)/g, "$1");
}

module.exports = { shellDir, load, untranslated, executable };
