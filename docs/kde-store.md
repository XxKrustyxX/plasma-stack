# KDE Store listing

Text and settings for the Folder Stack page on store.kde.org: https://store.kde.org/p/2379769/

To publish a new version: build it (`bash build.sh`), then on the store go to your Products → Folder Stack → **Files** → **Add File(s)**, set the version, and add a **Changelog** entry.

## Basics

| Field | Value |
|---|---|
| Category | Plasma 6 Extensions → **Plasma 6 Widgets** |
| Title | Folder Stack |
| Version | 1.16 |
| License | GPL-2.0-or-later (GPLv2+) |
| Tags | dock, folder, stack, downloads, macos, files, panel |
| Homepage / source | https://github.com/XxKrustyxX/plasma-stack |
| File to upload | `dist/folder-stack-1.16.plasmoid` (made by `bash build.sh`) |
| Screenshots | `docs/screenshots/`: fan, grid, right-click-menu, type-to-filter, new-files-and-selection, stacked-folders, new-files-badge |

## Summary (one line)

A macOS-style Stack for your dock: a folder's newest files fan out or open in a grid.

## Description

Folder Stack puts a folder on your dock that works like a Stack in the macOS Dock. Click it and the folder's newest files fan up out of the dock, or open in a grid. Click a file to open it, or drag it anywhere. It shows your Downloads folder by default, and you can point it at any folder or add several Stacks.

**Features**
- Fan, Grid, or Automatic (fan when the files fit, grid when there are more)
- Previews: pictures, PDF pages, video frames, album art, office documents
- Right-click a file: Open, Open With, Show in file manager, Rename, Copy Location, Move to Bin
- Select several files with Ctrl-click / Shift-click and drag or act on them together
- Just start typing to filter by name
- New files get a dot, and the dock icon shows how many arrived since you last looked
- Downloads in progress show live, with a bar on the dock icon and a bounce when they finish
- Drop files onto the icon (Move / Copy menu), or hold them there and the stack opens so you can drop them into a folder inside
- Open folders inside the stack, stacked on top of each other
- Works on any panel edge: the fan hangs down from a top dock, and side docks get the grid
- Choose the dock icon for each Stack

**Requirements**
Plasma 6. Tested on Fedora 44, Plasma 6.7.5, Wayland; it should work on other distros and older Plasma 6 releases but hasn't been tested there.
On **Debian / Ubuntu / Kubuntu** you may need: `qml6-module-qt-labs-folderlistmodel qml6-module-qtquick-dialogs qml6-module-org-kde-iconthemes`.
Optional, for previews: `python3`, `poppler-utils` (PDF), `ffmpeg` (video, album art), `libgsf` (office documents).
Full list and per-distro package names: https://github.com/XxKrustyxX/plasma-stack#dependencies

Bug reports and "it works on my distro" reports are very welcome on GitHub.

## Changelog (for 1.16)

- Follows the dock's edge: the fan hangs down from a top dock; side docks always get the grid
- Previews are remade when a file is replaced by an older copy
- New name: Folder Stack

Full history: https://github.com/XxKrustyxX/plasma-stack/blob/main/CHANGELOG.md
