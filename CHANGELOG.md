# Changelog

## 1.0.0

First release as a plugin. Until now T3 Code was a widget built into the
Cybex OS shell; it moved out so people who want it install it, and it can be
released on its own.

- The same chip and panel as the built-in widget: T3 Connect sign-in, the
  running/waiting/monitoring count on the chip, the inbox, threads with
  approvals, questions, plans and diffs, new threads with model and option
  pickers, settle, snooze, pin and stop.
- Keeps the built-in's state files, so an existing sign-in, unsent drafts and
  model favourites carry over (see README, “Coming from the built-in widget”).
- One setting, **Status label** (`showLabel`, on by default), as before. The
  word is also left out when the widget's width has no room for it.
- Says plainly when Node.js is missing instead of reporting a failed sign-in,
  and does not keep retrying until something changes.
- Opens and closes over IPC: `qs ipc call digitalpals.t3code open|close|toggle`
  (through the shell's `omarchy-shell` helper).
