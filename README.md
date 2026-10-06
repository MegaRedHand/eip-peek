# eip-peek

See an EIP's title without leaving what you're reading.

```
  ...this is blocked on 7805 landing first...
                        ▔▔▔▔
                         ┌────────────────────────────────────────────────────────┐
                         │ EIP-7805: Fork-choice enforced Inclusion Lists (FOCIL) │
                         │ forkcast.org                                           │
                         └────────────────────────────────────────────────────────┘
```

Two tools, set up independently:

| | [macOS Quick Action](#macos-quick-action) | [Chrome extension](#chrome-extension) |
|---|---|---|
| Works in | Any app, including the Slack desktop app | Web pages in Chrome, including Slack in the browser |
| Trigger | Select a number, press a hotkey | Double-click a number |
| Closes | Next click anywhere else, or switching apps | Next click anywhere else, Escape, or scrolling |
| Click the label | Opens the EIP's page | Opens the EIP's page |

## Where titles come from

Both tools check [forkcast.org](https://forkcast.org) first, since it also
tracks EIPs still sitting in a PR, then
[eips.ethereum.org](https://eips.ethereum.org), which also covers ERCs.

forkcast's full index is one file, so both tools cache it for a day (macOS:
`~/Library/Caches/eip-title/forkcast-eips.json`; Chrome: extension storage).
eips.ethereum.org is fetched live.

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
