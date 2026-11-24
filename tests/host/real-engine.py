#!/usr/bin/env python3
"""Load the T3 Code plugin in the real Cybex OS Quickshell host, headless.

Usage, from a Cybex OS checkout's development shell (it supplies qs, sway and
dbus-run-session):

    nix develop /path/to/CybexOS -c python3 tests/host/real-engine.py \
        --cybexos /path/to/CybexOS [--out DIR]

The Cybex OS checkout is only read. Everything else (home, config, state,
runtime directory, session bus, a two-output headless Sway) is disposable and
removed afterwards, so this never touches a desktop session or installed
plugins. Adapted from Cybex OS's tests/user-plugins.py.
"""

from __future__ import annotations

import argparse
from contextlib import ExitStack
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import tempfile
import time

PLUGIN = Path(__file__).resolve().parents[2]
PLUGIN_ID = "digitalpals.t3code"
# The dev shell names its D-Bus session config; the default path may not exist.
DBUS = ["dbus-run-session", *(["--config-file", os.environ["CYBEXOS_DBUS_SESSION_CONFIG"]]
                              if os.environ.get("CYBEXOS_DBUS_SESSION_CONFIG") else []), "--"]
# Package files; tests and repository metadata are not installed.
SKIP = {".git", ".github", "tests"}
ERRORS = re.compile(
    r"(?:Type|Reference|Range|Syntax)Error|Binding loop|Failed to load configuration"
    r"|is not a type|is not installed|Cannot assign|Unable to assign|Could not set|QML \w+: ")


def live_group_members(pgid):
    try:
        os.killpg(pgid, 0)
    except ProcessLookupError:
        return []
    members = []
    for stat in Path("/proc").glob("[0-9]*/stat"):
        try:
            state, _, group = stat.read_text().rsplit(")", 1)[1].split()[:3]
        except (OSError, ValueError):
            continue
        if int(group) == pgid and state != "Z":
            members.append(int(stat.parent.name))
    return members


def end_session(process):
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait()
    deadline = time.monotonic() + 3
    while members := live_group_members(process.pid):
        if time.monotonic() > deadline:
            raise RuntimeError(f"processes survived SIGKILL: {members}")
        time.sleep(0.02)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cybexos", required=True, type=Path,
                        help="a Cybex OS checkout (read only)")
    parser.add_argument("--out", type=Path, help="directory for chip/panel screenshots")
    parser.add_argument("--keep-log", action="store_true", help="print the whole qs log")
    args = parser.parse_args()
    shell = args.cybexos.resolve() / "desktop/quickshell"
    helper = shell / "scripts/user-plugins.py"
    for tool in ("qs", "sway", "dbus-run-session"):
        if not shutil.which(tool):
            raise SystemExit(f"{tool} is required; run inside the Cybex OS dev shell")

    # A short path: Quickshell's IPC socket must fit in sockaddr_un.
    with tempfile.TemporaryDirectory(prefix="t3p-", dir="/tmp") as temporary, ExitStack() as stack:
        base = Path(temporary)
        env = dict(os.environ, HOME=str(base / "home"), XDG_CONFIG_HOME=str(base / "config"),
                   XDG_DATA_HOME=str(base / "data"), XDG_STATE_HOME=str(base / "state"),
                   XDG_RUNTIME_DIR=str(base / "run"), CYBEXOS_LANG="en")
        for key in ("CYBEXOS_USER_CONFIG_ROOT", "CYBEXOS_PLUGIN_ROOT", "WAYLAND_DISPLAY",
                    "DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE"):
            env.pop(key, None)
        (base / "run").mkdir(mode=0o700)
        (base / "home").mkdir()
        package = base / "data/cybexos/plugins" / PLUGIN_ID
        shutil.copytree(PLUGIN, package, ignore=lambda _, names: [n for n in names if n in SKIP])

        def cli(*command):
            return subprocess.run(["python3", str(helper), *command], env=env, text=True,
                                  capture_output=True, check=True)

        listed = json.loads(cli("list").stdout)
        entry = next(item for item in listed["plugins"] if item["id"] == PLUGIN_ID)
        assert not entry.get("error"), entry
        assert entry["kinds"] == ["bar-widget", "service"], entry
        cli("enable", PLUGIN_ID, "--section", "right", "--width", "140")
        entry = next(item for item in json.loads(cli("list").stdout)["plugins"]
                     if item["id"] == PLUGIN_ID)
        assert entry["enabled"] and not entry.get("error"), entry
        print(f"Manifest valid: {entry['name']} {entry['version']}, kinds {entry['kinds']}")

        env.update(QT_QPA_PLATFORM="wayland", WLR_BACKENDS="headless", WLR_RENDERER="pixman",
                   WLR_LIBINPUT_NO_DEVICES="1", WLR_HEADLESS_OUTPUTS="2")
        (base / "sway.conf").write_text("output HEADLESS-1 mode 1280x720\n")
        sway = base / "sway"
        shutil.copyfile(shutil.which("sway"), sway)
        sway.chmod(0o700)
        sway_log = stack.enter_context((base / "sway.log").open("w+"))
        compositor = subprocess.Popen([*DBUS, str(sway), "-c", str(base / "sway.conf")], env=env,
                                      stdout=sway_log, stderr=subprocess.STDOUT,
                                      start_new_session=True)
        stack.callback(end_session, compositor)
        deadline = time.monotonic() + 10
        sockets = []
        while time.monotonic() < deadline and compositor.poll() is None:
            sockets = [p for p in (base / "run").glob("wayland-*") if p.is_socket()]
            if sockets:
                break
            time.sleep(0.05)
        if not sockets:
            sway_log.seek(0)
            raise RuntimeError("headless compositor did not start: " + sway_log.read())
        env["WAYLAND_DISPLAY"] = sockets[0].name

        runtime = base / "runtime"
        shutil.copytree(shell, runtime)
        shutil.copy2(Path(__file__).with_name("shell.qml"), runtime / "shell.qml")
        out = args.out.resolve() if args.out else base / "out"
        out.mkdir(parents=True, exist_ok=True)
        omarchy = runtime / "compat/omarchy"
        test_env = dict(env, OMARCHY_PATH=str(omarchy), T3_PLUGIN_TEST_OUT=str(out),
                        PATH=str(omarchy / "bin") + os.pathsep + env["PATH"])
        # The installed shell adds QtWebSockets (the T3 transport) and the SVG
        # image plugin (brand marks); the dev shell names the same paths.
        for source, target in (("CYBEXOS_QML_IMPORT_PATH", "QML_IMPORT_PATH"),
                               ("CYBEXOS_QT_PLUGIN_PATH", "QT_PLUGIN_PATH")):
            if os.environ.get(source):
                test_env[target] = os.pathsep.join(
                    filter(None, [os.environ[source], os.environ.get(target, "")]))
        process = subprocess.Popen([*DBUS, "qs", "--no-color", "-p", str(runtime)], env=test_env,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                   start_new_session=True)
        try:
            output, _ = process.communicate(timeout=45)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            output, _ = process.communicate(timeout=3)
            raise AssertionError(output) from None
        finally:
            end_session(process)
        if args.keep_log:
            print(output)
        plugin_lines = [line for line in output.splitlines()
                        if PLUGIN_ID in line or "cybex-plugin-code" in line]
        errors = [line for line in output.splitlines() if ERRORS.search(line)]
        result = [line for line in output.splitlines() if "T3_PLUGIN_RESULT" in line]
        print("\n".join(result) or "no result line")
        if plugin_lines:
            print("Plugin log lines:\n  " + "\n  ".join(plugin_lines))
        assert any("T3_PLUGIN_RESULT pass" in line for line in result), output
        assert not errors, "QML errors:\n" + "\n".join(errors)
        shots = sorted(p.name for p in out.glob("*.png"))
        print(f"No QML errors. Screenshots: {', '.join(shots) or 'none'} in {out}")


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(SystemExit(143)))
    main()
