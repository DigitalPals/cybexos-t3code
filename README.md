# T3 Code for Cybex OS

Watch and steer your [T3 Code](https://github.com/pingdotgg/t3code) agents
from the Cybex OS menubar. The chip shows whether sessions are running,
waiting for you or done; click it for a panel where you read threads, answer
approvals and questions, start new threads, and settle, snooze, pin or stop
work. It connects through **T3 Connect** to the environments you linked
there.

This was a built-in Cybex OS widget until version 1.0.0 of this plugin. It
now installs separately, from Settings → Plugins.

## Requirements

- **Cybex OS** with Omarchy plugin support (`schemaVersion: 1` packages in
  Settings → Plugins). The plugin uses the shell's `qs.Ui` and `qs.Commons`
  plugin API only.
- **Node.js** (`node` on `PATH`; tested with Node.js 24). The sign-in and
  connection helper, `scripts/t3-cloud.mjs`, runs with it. Without it the
  chip stays off and its tooltip and the panel say *T3 Code needs Node.js*.
- **QtWebSockets** for QML. Cybex OS ships it; elsewhere the chip shows
  *QtWebSockets is not installed*.
- A browser and `xdg-open` for signing in and opening links.
- A T3 Connect account with at least one linked environment.

## Install

In **Settings → Plugins**, under **Cybex OS plugins**, press **Install** next
to T3 Code. Or from a terminal:

```bash
cybex plugin add https://github.com/DigitalPals/cybexos-t3code
cybex plugin enable digitalpals.t3code --section right --width 140
```

The widget sits in the right-hand plugin area by default. Update or remove it
with `cybex plugin update digitalpals.t3code` and
`cybex plugin remove digitalpals.t3code`; removing keeps your settings and
your T3 sign-in.

## Use

- **Click the chip** to open or close the panel. Press **Escape** to go back
  a page, or to close the panel from the inbox.
- **Sign in** from the panel. Your browser opens T3 Connect (Google or
  GitHub); when it finishes, the panel opens again by itself.
- The chip reads, in order of urgency: *N waiting* (amber: a session needs
  an approval or an answer), *N running*, *N monitoring*, *N done*, *idle*.
  While not connected it says *sign in*, *signing in…*, *no links*,
  *connecting…* or *off*; hover it for the reason.
- A desktop notification appears when a session starts waiting for you,
  finishes after working, or fails.

From scripts or key bindings (the shell's own IPC):

```bash
qs ipc call digitalpals.t3code toggle   # also: open, close
```

## Settings

In **Settings → Bar & Control Center → T3 Code**, or with `cybex plugin set`:

| Key | Default | What it does |
| --- | --- | --- |
| `showLabel` | `true` | Show the waiting/running word beside the T3 mark. With it off, the chip is the mark and the live dot. |

The word is also left out when the widget's width has no room for it. The
host gives every plugin a fixed width (120 by default); `--width 140` fits
every word.

## Privacy and security

- **Where your sign-in lives.** The helper keeps the T3 Connect session, its
  DPoP signing key and short-lived tokens in
  `$XDG_STATE_HOME/t3code-cloud/` (`~/.local/state/t3code-cloud/` by default),
  a directory only you can read (mode 0700, files 0600). The connection
  details the panel reads are in `t3code-bar.json` beside it. None of this is
  written to `plugins.json`, and the plugin's settings never hold secrets.
- **Who it talks to.** `clerk.t3.codes` (sign-in) and `relay.t3.codes`
  (relay credentials and tickets), then the T3 environment you linked. Every
  request goes over HTTPS except to a server on your own machine. Nothing is
  sent anywhere else.
- **Links** from a server or the relay are opened only when they are plain
  `http`/`https` URLs.
- **Notifications** show the thread's title and project name.
- **Sign out** by running `node scripts/t3-cloud.mjs logout` from the
  installed package (`~/.local/share/cybexos/plugins/digitalpals.t3code`).
- Like every Cybex OS plugin, this is trusted code running as you inside the
  desktop shell. It is not sandboxed.

## Coming from the built-in widget

Cybex OS removed its built-in T3 Code widget when this plugin was released.

- **Kept:** your T3 Connect sign-in and linked environment
  (`~/.local/state/t3code-cloud/`, `~/.local/state/t3code-bar.json`) and your
  starred models (`~/.local/state/cybexos/shell/t3-model-favorites.json`).
  Unsent drafts lived in the shell's memory and do not survive the switch,
  as they did not survive a shell restart.
- **Not carried over:** the widget's place in the bar and its *Status label*
  switch. Enable the plugin and set them again.

What works differently in a plugin:

- **Placement.** Plugins sit together in their section's plugin area; they
  cannot sit between built-in widgets, and they have a fixed width.
- **The panel** is the shell's plugin popup under the chip rather than the
  built-in attached panel that grew out of the bar. Moving the pointer to
  another built-in widget does not switch panels; click it instead.
- **Crowded bars.** The built-in dropped its word when the whole right side
  of the bar ran out of room. The plugin only knows its own width.
- **Network status.** The built-in waited for the network to come back
  before retrying a dropped connection; the plugin cannot read the shell's
  network state, so it keeps retrying with growing delays (up to two
  minutes). It still waits while you are away from the computer.
- **System check.** The shell's health report no longer lists T3 connection
  errors; the chip's tooltip and the panel still show them.
- **Colours** follow the shell theme through the plugin API: the foreground,
  background, accent and warning colours, the menubar's fill, corner and font
  size. The built-in also followed the high-contrast focus colour and the
  wallpaper palette's own text tones; the plugin derives its text tones from
  the theme's foreground.

## Development

```bash
tests/run                                   # unit tests, Node only
tests/run --host /path/to/CybexOS           # also the real-engine check
```

The real-engine check (`tests/host/real-engine.py`) installs the package in
a disposable home, validates and enables it with Cybex OS's own plugin
helper, and runs the real Quickshell host under a private, headless,
two-output Sway. It checks that the service and the widgets share one state,
that the chip and panel draw, that IPC closes the panel and that disabling
the plugin closes the connection, and it fails on any QML error. It reads the
Cybex OS checkout but never changes it or your desktop. `--out DIR` keeps its
screenshots.

Layout: `Widget.qml` (bar widget) and `Service.qml` (connection lifetime and
IPC) are the entry points. `Core/` holds the T3 client (connection, RPC,
threads, drafts, favourites), the theme adapter and shared controls; `Panel/`
holds the chip and the panel's pages. Each directory's `qmldir` must list
every type in it.

## Licence

MIT; see [LICENSE](LICENSE). Bundled marks and the icon font keep their own
licences; see [assets/README.md](assets/README.md).
