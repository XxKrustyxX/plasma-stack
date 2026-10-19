#!/bin/bash
# Installs (or updates) the Stack widget and adds it to the dock.
#
#   bash install.sh             install/update, add to the dock, restart Plasma
#   bash install.sh --no-dock   install/update only (add it yourself: right-click the panel > Add Widgets > Stack)
set -e
cd "$(dirname "$0")"

ID=io.github.xxkrustyxx.stack
add_to_dock=1
[ "$1" = "--no-dock" ] && add_to_dock=0

have() { command -v "$1" >/dev/null 2>&1; }

if ! have kpackagetool6; then
    echo "kpackagetool6 not found - this needs KDE Plasma 6." >&2
    exit 1
fi

# ---- Dependency check (warnings only) ----
missing=()
have kioclient || missing+=("kioclient (kde-cli-tools) - needed to move/copy files dropped on the stack")
have xdg-mime  || missing+=("xdg-mime (xdg-utils) - needed to show your file manager's name")

qml_dir=""
for q in qtpaths6 qtpaths-qt6 qtpaths; do
    if have "$q"; then qml_dir=$("$q" --query QT_INSTALL_QML 2>/dev/null) && break; fi
done
if [ -n "$qml_dir" ] && [ -d "$qml_dir" ]; then
    [ -d "$qml_dir/Qt/labs/folderlistmodel" ] || missing+=("Qt folder list QML module - REQUIRED, the widget won't load (Debian/Ubuntu: qml6-module-qt-labs-folderlistmodel)")
    [ -d "$qml_dir/QtQuick/Dialogs" ]         || missing+=("Qt Quick Dialogs QML module - needed for the folder picker in the settings (Debian/Ubuntu: qml6-module-qtquick-dialogs)")
fi

optional=()
have python3                || optional+=("python3 - previews of anything other than pictures")
have pdftoppm               || optional+=("pdftoppm (poppler-utils) - PDF previews")
have ffmpeg                 || optional+=("ffmpeg - video and album art previews")
have gsf-office-thumbnailer || optional+=("gsf-office-thumbnailer (libgsf) - office document previews")

if [ ${#missing[@]} -gt 0 ]; then
    echo "Warning - missing:"
    printf '  - %s\n' "${missing[@]}"
fi
if [ ${#optional[@]} -gt 0 ]; then
    echo "Optional, not installed (those files just show their normal icon):"
    printf '  - %s\n' "${optional[@]}"
fi

# ---- Install / update ----
kpackagetool6 -t Plasma/Applet -u package 2>/dev/null || kpackagetool6 -t Plasma/Applet -i package

# ---- Add it to the dock (the panel with the app icons) if it isn't there already ----
qdbus=""
for q in qdbus6 qdbus-qt6 qdbus; do
    if have "$q"; then qdbus=$q; break; fi
done

if [ $add_to_dock = 1 ]; then
    if [ -n "$qdbus" ]; then
        "$qdbus" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
for (const p of panels()) {
  if (p.widgets('org.kde.plasma.icontasks').length && !p.widgets('$ID').length) {
    p.addWidget('org.kde.plasma.marginsseparator');
    p.addWidget('$ID');
  }
}" >/dev/null || echo "Couldn't add it to the dock automatically - right-click the panel > Add Widgets > Stack."
    else
        echo "qdbus not found - add it yourself: right-click the panel > Add Widgets > Stack."
    fi
fi

# ---- Plasma caches widget code, so restart the shell to load this version ----
if have systemctl && systemctl --user is-active --quiet plasma-plasmashell 2>/dev/null; then
    systemctl --user restart plasma-plasmashell
elif have kquitapp6 && have kstart; then
    kquitapp6 plasmashell >/dev/null 2>&1 || true
    kstart plasmashell >/dev/null 2>&1 &
else
    echo "Log out and back in to load the new version."
fi

echo "Stack widget installed."
