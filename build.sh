#!/bin/bash
# Builds dist/folder-stack-<version>.plasmoid: the file for the KDE Store and GitHub releases.
# (A .plasmoid is a zip of the package folder; Plasma installs it with "Install Widget From Local File"
# or: kpackagetool6 -t Plasma/Applet -i folder-stack-<version>.plasmoid)
set -e
cd "$(dirname "$0")"

version=$(python3 -c 'import json; print(json.load(open("package/metadata.json"))["KPlugin"]["Version"])')
out="dist/folder-stack-$version.plasmoid"

mkdir -p dist
rm -f "$out"
(cd package && zip -qr -X "../$out" . -x '*/__pycache__/*' '*.pyc')

echo "Built $out"
unzip -l "$out" | tail -n +4 | head -n -2 | awk '{print "  " $4}'
