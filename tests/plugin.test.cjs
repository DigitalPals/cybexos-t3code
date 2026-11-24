// The plugin's own contract: its manifest, the host boundary it must keep,
// the Node launcher, and the state paths it shares with the old built-in.
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { shellDir, load } = require("./shell.cjs");

const read = relative => fs.readFileSync(path.join(shellDir, relative), "utf8");
const qmlFiles = dir => fs.readdirSync(path.join(shellDir, dir))
    .filter(name => name.endsWith(".qml")).map(name => path.join(dir, name));
const allQml = () => ["Widget.qml", "Service.qml", ...qmlFiles("Core"), ...qmlFiles("Panel")];

test("the manifest declares a bar widget and service with the built-in's defaults", () => {
    const manifest = JSON.parse(read("manifest.json"));
    assert.equal(manifest.schemaVersion, 1);
    assert.equal(manifest.id, "digitalpals.t3code");
    assert.equal(manifest.version, "1.0.0");
    assert.equal(manifest.license, "MIT");
    assert.deepEqual(manifest.kinds, ["bar-widget", "service"]);
    assert.deepEqual(manifest.entryPoints, { barWidget: "Widget.qml", service: "Service.qml" });
    for (const entry of Object.values(manifest.entryPoints))
        assert.ok(fs.existsSync(path.join(shellDir, entry)), entry);
    assert.notEqual(manifest.keepLoaded, true);
    const widget = manifest.barWidget;
    assert.equal(widget.defaultSection, "right");
    assert.equal(widget.allowMultiple, false);
    // Cybex OS's modOpts default for the old built-in: { t3: { showLabel: true } }.
    assert.deepEqual(widget.defaults, { showLabel: true });
    assert.deepEqual(widget.schema.map(entry => [entry.key, entry.type, entry.defaultValue]),
        [["showLabel", "boolean", true]]);
    for (const entry of widget.schema)
        assert.deepEqual(widget.defaults[entry.key], entry.defaultValue, entry.key);
    assert.match(read("Widget.qml"), /setting\("showLabel", true\)/);
});

test("no plugin file reaches into the shell's private types", () => {
    for (const file of allQml()) {
        const source = read(file);
        const imports = source.match(/^import\s+[^\n]+/gm) || [];
        for (const line of imports) {
            assert.doesNotMatch(line, /"(\.\.\/)+(Common|Bar|Popovers|Settings)"/, `${file}: ${line}`);
            assert.doesNotMatch(line, /\bqs\.(?!Ui\b|Commons\b)/, `${file}: ${line}`);
        }
        assert.doesNotMatch(source, /Quickshell\.shellDir/, `${file} must not read the shell's tree`);
        assert.doesNotMatch(source, /\b(Popouts|Notifs|NetworkStatus|FocusModality|SettingsHelpers\.js)\b(?=[.(])/,
            `${file} uses a shell singleton`);
    }
    const helper = read("scripts/t3-cloud.mjs");
    assert.doesNotMatch(helper, /Common\/|SHELL_DIR|"popouts"/);
});

test("each directory's qmldir lists every type, singletons as singletons", () => {
    for (const dir of ["Core", "Panel"]) {
        const entries = new Map(read(`${dir}/qmldir`).split("\n")
            .map(line => line.trim()).filter(line => line && !line.startsWith("#"))
            .map(line => {
                const parts = line.split(/\s+/);
                return parts[0] === "singleton" ? [parts[1], { file: parts[2], singleton: true }]
                    : [parts[0], { file: parts[1], singleton: false }];
            }));
        for (const file of qmlFiles(dir)) {
            const name = path.basename(file, ".qml");
            const singleton = /^pragma Singleton$/m.test(read(file));
            if (name === "T3Socket") {
                // Loaded by path, so a missing QtWebSockets fails one Loader.
                assert.ok(!entries.has(name), "T3Socket must stay out of the qmldir");
                continue;
            }
            assert.ok(entries.has(name), `${dir}/qmldir is missing ${name}`);
            assert.equal(entries.get(name).file, `${name}.qml`);
            assert.equal(entries.get(name).singleton, singleton, `${name} singleton flag`);
        }
        for (const [name, entry] of entries)
            assert.ok(fs.existsSync(path.join(shellDir, dir, entry.file)), `${dir}/${name}`);
    }
});

test("the launcher says plainly when Node.js is missing", t => {
    const Launch = load("Launch.js");
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "t3-launch-"));
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const script = path.join(dir, "helper.mjs");
    fs.writeFileSync(script, "console.log(JSON.stringify(process.argv.slice(2)));\n");
    const run = (command, env) => spawnSync("/bin/sh", command.slice(1), { env, encoding: "utf8" });

    const command = Launch.helperCommand(script, "ticket");
    assert.equal(command[0], "sh");
    const missing = run(command, { PATH: path.join(dir, "empty") });
    assert.equal(missing.status, Launch.NODE_MISSING_EXIT);
    assert.equal(missing.stderr.trim(), Launch.NODE_MISSING_MESSAGE);
    assert.match(Launch.NODE_MISSING_MESSAGE, /Node\.js/);

    const present = run(command, { PATH: path.dirname(process.execPath) });
    assert.equal(present.status, 0, present.stderr);
    assert.deepEqual(JSON.parse(present.stdout), ["ticket"]);

    assert.equal(Launch.localPath("file:///a%20b/scripts/t3-cloud.mjs"), "/a b/scripts/t3-cloud.mjs");
    const connection = read("Core/T3Connection.qml");
    assert.match(connection, /lastExit === T3Host\.nodeMissingExit\)[\s\S]{0,400}?connectionError = T3Host\.nodeMissingMessage;[\s\S]{0,200}?return;/,
        "a missing node is reported once, not retried");
});

test("sign-in, drafts and favorites keep the built-in's state paths", () => {
    const connection = read("Core/T3Connection.qml");
    assert.match(connection, /Quickshell\.env\("XDG_STATE_HOME"\)\s*\|\| \(Quickshell\.env\("HOME"\) \+ "\/\.local\/state"\)/);
    assert.match(connection, /path: stateHome \+ "\/t3code-bar\.json"/);
    const helper = read("scripts/t3-cloud.mjs");
    assert.match(helper, /const privateStateDir = path\.join\(stateRoot, "t3code-cloud"\);/);
    assert.match(helper, /path\.join\(stateRoot, "t3code-bar\.json"\)/);
    assert.match(read("Core/T3Favorites.qml"),
        /"\/\.local\/state\/cybexos\/shell\/t3-model-favorites\.json"/);
});

test("bundled marks cover every provider glyph and exist on disk", () => {
    const icons = read("Core/BrandIcons.qml");
    const names = JSON.parse(icons.match(/readonly property var names: (\[[^\]]*\])/)[1]);
    const Helpers = load("T3CodeHelpers.js");
    for (const hint of ["claudeAgent", "codex", "gpt-5", "kimi", "moonshot"])
        assert.ok(names.includes(Helpers.providerIconName(hint)), hint);
    assert.ok(names.includes("t3"));
    for (const match of icons.matchAll(/:\s*"([a-z0-9-]+\.svg)"/g))
        assert.ok(fs.existsSync(path.join(shellDir, "assets", match[1])), match[1]);
    assert.ok(fs.existsSync(path.join(shellDir, "assets/tabler/outline.ttf")));
});

test("the theme adapter's contrast helpers reach their floors", () => {
    const Contrast = load("Contrast.js");
    for (const background of ["#1b1a18", "#f1f0f5", "#3355aa"]) {
        for (const value of ["#60a5fa", "#ffc26e", "#b5761e"]) {
            const out = Contrast.ensureContrast(value, background, 4.5);
            assert.ok(Contrast.contrastRatio(out, background) >= 4.5 - 1e-6, `${value} on ${background}`);
        }
        const ladder = Contrast.textPalette(background, Contrast.foregroundFor(background));
        for (const [step, floor] of [["textHi", 7], ["textMid", 7], ["textLow", 5.5], ["textFaint", 4.5]])
            assert.ok(Contrast.contrastRatio(ladder[step], background) >= floor - 0.05, step);
    }
});

test("the Dutch catalog carries only text this plugin shows", () => {
    const { MESSAGES } = load("i18n/nl.js");
    const sources = [...allQml(), ...fs.readdirSync(path.join(shellDir, "Core"))
        .filter(name => name.endsWith(".js")).map(name => path.join("Core", name))].map(read).join("\n");
    const keys = Object.keys(MESSAGES);
    assert.ok(keys.length > 50);
    for (const key of keys)
        assert.ok(sources.includes(JSON.stringify(key)), key);
});
