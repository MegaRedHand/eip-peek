# eip-peek

See an EIP's title, a short description and its network-upgrade status without
leaving what you're reading.

```
  ...this is blocked on 7805 landing first...
                        ▔▔▔▔
                         ┌─────────────────────────────────────────────────────────────┐
                         │ EIP-7805: Fork-choice enforced Inclusion Lists (FOCIL)      │
                         │ Allow a committee of validators to force-include a set of   │
                         │ transactions in every block                                 │
                         │ Scheduled for Hegota (headliner) · Declined for Glamsterdam │
                         │ forkcast.org                                                │
                         └─────────────────────────────────────────────────────────────┘
```

Two tools, set up independently:

| | [macOS Quick Action](#macos-quick-action) | [Chrome extension](#chrome-extension) |
|---|---|---|
| Works in | Any app, including the Slack desktop app | Web pages in Chrome, including Slack in the browser |
| Trigger | Select a number, press a hotkey | Double-click a number |
| Closes | Next click anywhere else, or switching apps | Next click anywhere else, switching tabs, Escape, or scrolling |
| Click the label | Opens the EIP's page | Opens the EIP's page |

For the terminal, a [zsh plugin](#zsh-plugin) runs the same lookups.

Older EIPs predate the description field (EIP-1559, for example), so they show
the title only.

The upgrade status comes from forkcast alone: the current stage in each network
upgrade forkcast tracks the EIP for, newest upgrade first. EIPs forkcast
doesn't track for any upgrade show no status.

## Where titles come from

Both tools check [forkcast.org](https://forkcast.org) first, since it also
tracks EIPs still sitting in a PR, then
[eips.ethereum.org](https://eips.ethereum.org), which also covers ERCs.

| Source | Cached for | macOS cache | Chrome cache |
|---|---|---|---|
| forkcast's full index (one file) | 1 day | `~/Library/Caches/eip-title/forkcast-eips.json` | extension storage |
| eips.ethereum.org, per EIP | 7 days | `~/Library/Caches/eip-title/eips/<N>` | extension storage |

Numbers neither site knows aren't cached, so a newly published EIP shows up
right away. When a refresh fails, the stale entry is used instead.

## macOS Quick Action

### Requirements

- macOS 15 or later (uses the bundled `/usr/bin/jq`)
- Xcode Command Line Tools, for `swiftc`: `xcode-select --install`

### Setup

1. Clone and install:

   ```sh
   git clone git@github.com:MegaRedHand/eip-peek.git
   cd eip-peek
   ./macos/install.sh
   ```

   This builds the label helper and installs:

   | What | Where |
   |---|---|
   | `eip-title` (lookup script) | `~/.local/bin/eip-title` |
   | `eip-hud` (label helper) | `~/.local/bin/eip-hud` |
   | "EIP Title" Quick Action | `~/Library/Services/EIP Title.workflow` |

   Re-run `./macos/install.sh` after pulling changes.

2. Assign a hotkey: **System Settings → Keyboard → Keyboard Shortcuts… →
   Services → Text → EIP Title**. Pick a combination your apps don't already
   use.

3. Try it: double-click a number such as 7805 in any app and press the hotkey.

### Usage

| Way | How |
|---|---|
| Hotkey | Select the number (double-click it), press the hotkey |
| Menu | Select the number, then right-click → **Services → EIP Title** |
| Terminal | `eip-title 7805`, or `echo "see EIP-4337" \| eip-title` |
| Scripts | `eip-title --json 7805` prints `{title, description, status, url}` |

The first number in the selection is used, so selecting `EIP-1559` works too.

Slack's desktop app may not list Services in its right-click menu. The hotkey
works there, and so does the menu bar's **Slack → Services**.

### How it works

```
selection ──▶ Quick Action ──▶ eip-title ──▶ eip-hud (label at the cursor)
```

- The label never takes focus from the app you're in.
- It closes through a global mouse monitor, which needs no Accessibility
  permission. For the same reason Escape doesn't close it: watching keystrokes
  would need that permission.
- A label nobody clicks away closes on its own after 5 minutes.
- A new lookup replaces any label still on screen.

### Uninstall

```sh
rm ~/.local/bin/eip-title ~/.local/bin/eip-hud
rm -r ~/Library/Services/"EIP Title.workflow" ~/Library/Caches/eip-title
```

## zsh plugin

Terminal commands in `zsh/eip.plugin.zsh`. They build on the macOS install's
`eip-title`, so run `./macos/install.sh` first.

| Command | What it does |
|---|---|
| `eipeek 7805 1559` | Title, description and upgrade status of each EIP |
| `eip 7805` | Opens the EIP's page; forkcast's for EIPs still open as PRs |
| `eipraw 7805` | Prints the EIP's markdown: EIPs repo, then ERCs repo, then the open PR (needs [`gh`](https://cli.github.com)) |
| `eipread 7805` | Opens that markdown in vim |

Numbers work in any form: `1559`, `EIP-1559`, `ERC-20`.

### Setup

With oh-my-zsh, link the folder in as the `eip` plugin, then add `eip` to
`plugins=(...)` in `~/.zshrc`:

```sh
ln -s "$PWD/zsh" ~/.oh-my-zsh/custom/plugins/eip
```

Without oh-my-zsh, add this to `~/.zshrc`:

```sh
source /path/to/eip-peek/zsh/eip.plugin.zsh
```

## Chrome extension

### Setup

1. Open `chrome://extensions` and turn on **Developer mode** (top right).
2. Click **Load unpacked** and pick the `chrome/` folder of this repo.
3. Reload tabs that were already open; the extension only runs in pages loaded
   after it's installed.

After pulling changes, click the reload icon on the extension's card in
`chrome://extensions`.

### Usage

Double-click a number to see the popup:

- A bare number needs **4-5 digits**, so double-clicking ordinary numbers
  stays quiet.
- After an `EIP-` or `ERC-` prefix any length works: `EIP-20`, `ERC-721`.
- Selecting `EIP-1559` by dragging works too.

Double-clicking a **link** follows it instead of selecting the number. To look
up a linked number, hold Option and drag across it.

### Icon

The icons in `chrome/icons/` are drawn by `make-icons.swift`. To change them,
edit it and run `swift make-icons.swift` from that folder.

### Uninstall

Click **Remove** on the extension's card in `chrome://extensions`.
