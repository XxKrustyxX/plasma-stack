# Changelog

## 1.9
- Previews: PDF first page, video frame, album art, office document previews. Reuses the shared freedesktop thumbnail cache, makes missing ones in the background, and deletes unused ones after 60 days. Setting to turn previews off.
- Downloads: in-progress Firefox/Chrome/Edge/Brave/Opera downloads are shown under their real name with a live size, the dock icon shows a progress bar, and it bounces when a download finishes (can be turned off).

## 1.8
- The popup is only built while the stack is open and is freed when it closes.

## 1.7
- "Open in …" buttons use the default file manager's name instead of always saying Dolphin.

## 1.6
- Folders inside the stack can open in place (grid, with a back button) or stacked on top (grid and fan), with the folders you came through visible behind it.
- New setting: *Folders open*.

## 1.3
- Tooltip with the folder's name when hovering over the dock icon.

## 1.2
- Drag files out of the fan or grid.
- Drop files onto the dock icon: Move Here / Copy Here / Cancel menu, <kbd>Shift</kbd> to move, <kbd>Ctrl</kbd> to copy.
- Fixed the empty space left in the panel after dragging over it.

## 1.1
- *Open as* setting: Fan, Grid or Automatic.
- Fixed a missing icon for files like `backup.tar.gz`.

## 1.0
- First version: a dock folder that fans out its newest files.
