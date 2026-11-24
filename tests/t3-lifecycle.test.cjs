// Connection lifetime for the T3 socket: when it may exist at all, when a
// failed link is retried, and how fast. The singletons need a live Qt engine,
// so the bindings that decide it are lifted out of the source and run against
// stand-ins, and the wiring around them is checked textually. Ported from
// Cybex OS's tests/quickshell/t3-hermes-lifecycle.test.cjs (its T3 half).
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { shellDir, load } = require("./shell.cjs");

function read(relative) {
    return fs.readFileSync(path.join(shellDir, relative), "utf8");
}

// The body of the first `{ … }` block following `marker`.
function blockAfter(source, marker) {
    const at = source.indexOf(marker);
    assert.notEqual(at, -1, `missing ${marker}`);
    const open = source.indexOf("{", at + marker.length - 1);
    let depth = 0;
    for (let i = open; i < source.length; i++) {
        if (source[i] === "{")
            depth++;
        else if (source[i] === "}" && --depth === 0)
            return source.slice(open + 1, i);
    }
    throw new Error(`unbalanced block after ${marker}`);
}

// Evaluate a QML binding body against stand-in singletons.
function binding(body, scope) {
    const names = Object.keys(scope);
    return new Function(...names, body)(...names.map(name => scope[name]));
}

test("Core/T3Connection.qml wants a link only while the plugin's service is attached", () => {
    // A binding expression rather than a block: evaluate it directly.
    const expression = read("Core/T3Connection.qml")
        .match(/readonly property bool enabled:\s*([^\n]+)/)[1];
    const enabled = active => binding("return " + expression + ";", { T3Host: { active } });
    assert.equal(enabled(true), true);
    assert.equal(enabled(false), false,
        "a disabled plugin must not hold a socket for the shell's lifetime");
});

test("the service attaches T3Host for exactly its own lifetime", () => {
    const service = read("Service.qml");
    const host = read("Core/T3Host.qml");
    assert.match(service, /Component\.onCompleted:\s*T3Host\.attach\(\)/);
    assert.match(service, /Component\.onDestruction:\s*T3Host\.detach\(\)/);
    assert.match(host, /readonly property bool active:\s*attachments > 0/);
    assert.match(blockAfter(host, "function detach()"), /Math\.max\(0, attachments - 1\)/);
    const manifest = JSON.parse(read("manifest.json"));
    assert.notEqual(manifest.keepLoaded, true,
        "a kept service would hold the old code's singletons across a reload");
});

test("T3 gates every connection path on the module and tears down when it goes", () => {
    const connection = read("Core/T3Connection.qml");
    assert.match(blockAfter(connection, "function connect()"),
        /if \(!paired\) \{[\s\S]*?\}\s*[\s\S]*?if \(!enabled\)\s*return;/,
        "connect() is the one funnel; it must refuse while nothing wants the link");
    const changed = blockAfter(connection, "onEnabledChanged:");
    assert.match(changed,
        /if \(enabled\) \{[\s\S]*socketLoader\.active = true;[\s\S]*connect\(\);[\s\S]*return;\s*\}/,
        "re-enabling must restore the wrapper resetTransport destroyed, then connect");
    assert.match(changed, /resetTransport\(\);\s*connectionError = "";/,
        "disabling must close the link and drop its stale failure");
});

// What a transport's stableTimer does when a link has stayed up.
function stableTrigger(source) {
    return blockAfter(source.slice(source.indexOf("id: stableTimer")), "onTriggered:");
}

// The socket-open branch of a transport's status handler.
function openBranch(source) {
    const handler = blockAfter(source, "function onSocketStatusChanged(");
    return blockAfter(handler, "=== 1)");
}

test("T3 resets its backoff only once the link has proven healthy", () => {
    const connection = read("Core/T3Connection.qml");
    const facade = read("Core/T3Code.qml");
    const opened = openBranch(connection);
    assert.doesNotMatch(opened, /retrySecs/,
        "an accept-then-drop server must not be retried at a fixed five seconds");
    assert.match(opened, /stableTimer\.epoch = epoch;\s*stableTimer\.restart\(\);/);
    assert.match(blockAfter(connection, "function markHealthy()"),
        /stableTimer\.stop\(\);\s*retrySecs = 5;/);
    assert.match(connection, /id: stableTimer\s*interval: 60000/);
    assert.match(stableTrigger(connection),
        /epoch === root\.sessionEpoch && root\.state === "connected"\)\s*root\.markHealthy\(\);/);
    assert.match(blockAfter(connection, "function scheduleRetry(epoch)"),
        /stableTimer\.stop\(\);[\s\S]*retrySecs = Math\.min\(retrySecs \* 2, 120\);/,
        "a drop must cancel a pending proof and keep doubling");

    // The shell stream proves the link, and ending it with a Failure says why.
    const handle = blockAfter(facade, "function handleMessage(text)");
    assert.match(handle,
        /const wasReady = T3Threads\.shellReady;\s*dirty = T3Threads\.applyItems\(msg\.values\) \|\| dirty;[\s\S]*?if \(!wasReady && T3Threads\.shellReady\)\s*T3Connection\.markHealthy\(\);/);
    const exit = blockAfter(handle, 'msg._tag === "Exit")');
    assert.match(exit,
        /if \(msg\.exit && msg\.exit\._tag === "Failure"\)\s*T3Connection\.connectionError = T3Rpc\.failureMessage\(msg,[\s\S]*?\);\s*T3Connection\.scheduleRetry\(\);/);
    assert.doesNotMatch(exit, /markHealthy|retrySecs/);
});

test("reconnect holds: known-offline waits unless the server is local, idle waits", () => {
    const Helpers = load("T3CodeHelpers.js");
    assert.equal(Helpers.isLoopbackOrigin("http://127.0.0.1:3773"), true);
    assert.equal(Helpers.isLoopbackOrigin("https://localhost"), true);
    assert.equal(Helpers.isLoopbackOrigin("ws://[::1]:9120/ws"), true);
    assert.equal(Helpers.isLoopbackOrigin("https://t3.example.test"), false);
    assert.equal(Helpers.isLoopbackOrigin("http://127.0.0.1.example.test"), false);
    assert.equal(Helpers.isLoopbackOrigin(""), false);
    assert.equal(Helpers.isLoopbackOrigin(null), false);

    assert.equal(Helpers.reconnectHold(true, false, false, false), "network");
    assert.equal(Helpers.reconnectHold(true, false, true, false), "",
        "a loopback server needs no network");
    assert.equal(Helpers.reconnectHold(false, false, false, false), "",
        "an unknown network state must not strand the link");
    assert.equal(Helpers.reconnectHold(true, true, false, true), "idle");
    assert.equal(Helpers.reconnectHold(true, false, false, true), "network");
    assert.equal(Helpers.reconnectHold(true, true, false, false), "");
});

// Runs T3Connection's own retry functions and edge handlers against
// stand-ins for the QML objects they touch.
function t3Harness(overrides = {}) {
    const source = read("Core/T3Connection.qml");
    const timer = () => ({
        running: false, interval: 0, epoch: -1,
        restart() { this.running = true; },
        stop() { this.running = false; },
    });
    const scope = {
        Helpers: load("T3CodeHelpers.js"),
        T3Host: { idle: false },
        sessionEpoch: 4,
        state: "connected",
        enabled: true,
        paired: true,
        websocketsMissing: false,
        host: "https://t3.example.test",
        retrySecs: 5,
        connects: 0,
        drops: 0,
        socketLoader: { item: null },
        retryTimer: timer(),
        stableTimer: timer(),
        socketConnectTimeout: timer(),
        dropped() { scope.drops++; },
        connect() { scope.connects++; scope.state = "connecting"; },
        ...overrides,
    };
    scope.root = scope;
    const compile = (params, body) =>
        new Function("scope", `with (scope) { return function (${params}) {${body}}; }`)(scope);
    for (const [name, params] of [["scheduleRetry", "epoch"], ["retryHold", "resumed"],
        ["resumeReconnect", "resetBackoff, resumed"]])
        scope[name] = compile(params, blockAfter(source, `function ${name}(${params})`));
    const onResumed = compile("", blockAfter(source, "function onResumed()"));
    const fire = compile("", `with (retryTimer) {${blockAfter(
        source.slice(source.indexOf("id: retryTimer")), "onTriggered:")}}`);
    return { scope, onResumed, fire };
}

test("T3 holds its retries while idle and resumes on the edge", () => {
    // The shell's NetworkStatus is private to it: the plugin never holds for
    // the network, so a drop always arms the backoff unless idle.
    let { scope, onResumed, fire } = t3Harness({ retrySecs: 40 });
    assert.doesNotMatch(read("Core/T3Connection.qml"), /NetworkStatus|Activity\./);
    scope.scheduleRetry(4);
    assert.equal(scope.retryTimer.running, true);

    // Idle: no retry, and the resume edge connects even while `idle` itself
    // has not settled yet.
    ({ scope, onResumed, fire } = t3Harness({ retrySecs: 40 }));
    scope.T3Host.idle = true;
    scope.scheduleRetry(4);
    assert.equal(scope.state, "offline");
    assert.equal(scope.drops, 1);
    assert.equal(scope.retryTimer.running, false, "no retry may start while idle");
    onResumed();
    assert.equal(scope.connects, 1);
    assert.equal(scope.retrySecs, 40, "resuming alone keeps the backoff");

    // A pending retry that fires into a hold does nothing.
    ({ scope, onResumed, fire } = t3Harness());
    scope.scheduleRetry(4);
    assert.equal(scope.retryTimer.running, true);
    assert.equal(scope.retryTimer.interval, 5000);
    assert.equal(scope.retrySecs, 10);
    scope.T3Host.idle = true;
    fire();
    assert.equal(scope.connects, 0);
    scope.T3Host.idle = false;
    fire();
    assert.equal(scope.connects, 1);

    // Only a transiently offline link is resumed.
    for (const blocked of [{ state: "signed-out" }, { state: "connected" },
        { enabled: false, state: "offline" }, { paired: false, state: "offline" },
        { websocketsMissing: true, state: "offline" }]) {
        ({ scope, onResumed } = t3Harness(blocked));
        onResumed();
        assert.equal(scope.connects, 0, JSON.stringify(blocked));
    }
    ({ scope } = t3Harness({ enabled: false }));
    scope.scheduleRetry(4);
    assert.equal(scope.retryTimer.running, false, "a disabled link arms nothing");
});

test("T3 fetches its environment descriptor once per session", () => {
    const connection = read("Core/T3Connection.qml");
    const fetch = blockAfter(connection, "function fetchDescriptor(epoch)");
    assert.match(fetch, /^\s*if \(descriptorEpoch === epoch\)\s*return;/);
    assert.match(fetch, /root\.environmentCapabilities = [^\n]*\n\s*root\.descriptorEpoch = epoch;/,
        "only a descriptor that was actually read counts as loaded");
    assert.match(blockAfter(connection, "function resetTransport()"), /sessionEpoch\+\+/,
        "a new session must fetch its own descriptor");
});

