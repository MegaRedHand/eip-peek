# eip-peek

Select an EIP number anywhere on macOS, press a hotkey, and its title shows up
in a small label next to the cursor.

```
  ...this is blocked on 7805 landing first...
                        ▔▔▔▔
                         ┌────────────────────────────────────────────────────────┐
                         │ EIP-7805: Fork-choice enforced Inclusion Lists (FOCIL) │
                         │ forkcast.org                                           │
                         └────────────────────────────────────────────────────────┘
```

- **Click the label** to open the EIP's page.
- **Click anywhere else** or **switch apps** to close it.
- It never takes focus from the app you're in.

Titles come from [forkcast.org](https://forkcast.org) first, since it also
tracks EIPs still sitting in a PR, then from
[eips.ethereum.org](https://eips.ethereum.org), which also covers ERCs.

## Requirements

- macOS 15 or later (uses the bundled `/usr/bin/jq`)
- Xcode Command Line Tools, for `swiftc`: `xcode-select --install`

## Setup

1. Clone and install:

   ```sh
   git clone git@github.com:MegaRedHand/eip-peek.git
   cd eip-peek
   ./install.sh
   ```

   This builds the label helper and installs:

   | What | Where |
   |---|---|
   | `eip-title` (lookup script) | `~/.local/bin/eip-title` |
   | `eip-hud` (label helper) | `~/.local/bin/eip-hud` |
   | "EIP Title" Quick Action | `~/Library/Services/EIP Title.workflow` |

2. Assign a hotkey: **System Settings → Keyboard → Keyboard Shortcuts… →
   Services → Text → EIP Title**. Pick a combination your apps don't already
   use.

3. Try it: double-click a number such as 1559 in any app and press the hotkey.

## Usage

| Way | How |
|---|---|
| Hotkey | Select the number (double-click it), press the hotkey |
| Menu | Select the number, then right-click → **Services → EIP Title** |
| Terminal | `eip-title 7805`, or `echo "see EIP-4337" \| eip-title` |

The first number in the selection is used, so selecting `EIP-1559` works too.

Slack's desktop app may not list Services in its right-click menu. The hotkey
works there, and so does the menu bar's **Slack → Services**.

## How it works

```
selection ──▶ Quick Action ──▶ eip-title ──▶ eip-hud
                                   │           (label at the cursor)
                                   ├─ 1. forkcast.org/api/eips.json
                                   │     cached in ~/Library/Caches/eip-title/,
                                   │     refreshed daily
                                   └─ 2. eips.ethereum.org/EIPS/eip-N
                                         (page title, fetched live)
```

- `eip-hud` closes through a global mouse monitor, which needs no
  Accessibility permission. For the same reason Escape doesn't close it:
  watching keystrokes would need that permission.
- A label nobody clicks away closes on its own after 5 minutes.
- A new lookup replaces any label still on screen.

## Uninstall

```sh
rm ~/.local/bin/eip-title ~/.local/bin/eip-hud
rm -r ~/Library/Services/"EIP Title.workflow" ~/Library/Caches/eip-title
```
