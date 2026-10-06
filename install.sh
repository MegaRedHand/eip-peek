#!/bin/zsh
# Installs eip-peek: the lookup script and label helper into ~/.local/bin, and
# the "EIP Title" Quick Action into ~/Library/Services.
#
# The Quick Action calls ~/.local/bin/eip-title by that exact path, so the
# install location is fixed. Re-run after pulling changes.

set -euo pipefail
cd "${0:A:h}"

bin=~/.local/bin
services=~/Library/Services
mkdir -p $bin $services

echo "Building eip-hud..."
swiftc -O eip-hud.swift -o $bin/eip-hud
install -m 755 eip-title $bin/eip-title

rm -rf "$services/EIP Title.workflow"
cp -R "EIP Title.workflow" $services/
# Make macOS pick up the new service without logging out.
/System/Library/CoreServices/pbs -flush

echo "Installed. Try: eip-title 7805"
echo "Then assign a hotkey: System Settings > Keyboard > Keyboard Shortcuts... > Services > Text > EIP Title"
