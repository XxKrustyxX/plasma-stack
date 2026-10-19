#!/bin/bash
# Removes the Stack widget from every panel and uninstalls it.
#
#   bash uninstall.sh            also deletes its preview cache (~/.cache/stack-widget)
#   bash uninstall.sh --keep-cache
set -e

ID=io.github.xxkrustyxx.stack
have() { command -v "$1" >/dev/null 2>&1; }

for q in qdbus6 qdbus-qt6 qdbus; do
    if have "$q"; then
        "$q" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
for (const p of panels()) {
  for (const w of p.widgets('$ID')) w.remove();
}" >/dev/null || true
        break
    fi
done

kpackagetool6 -t Plasma/Applet -r "$ID" || true

if [ "$1" != "--keep-cache" ]; then
    rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/stack-widget"
fi

if have systemctl && systemctl --user is-active --quiet plasma-plasmashell 2>/dev/null; then
    systemctl --user restart plasma-plasmashell
fi

echo "Stack widget removed."
