# Changelog

## 1.16
- Follows the dock's edge: the fan hangs down from a top dock; a dock down the left or right always gets the grid (the settings page says so); the grid, stacked folders and bounce follow the edge too.
- Previews are remade when a file is replaced by a copy with an older date.
- Public name is now "Folder Stack" (easier to find in the widget list). Same widget id, so settings are kept.
- `build.sh` makes the `.plasmoid` file for releases.

## 1.15
- Drop into a subfolder: hold files over the dock icon and the stack opens; hold over a folder to open it, or over a folder behind to go back; drop on a folder or the box. Dragging out closes it.
- Files dragged from the stack onto one of its own folders move into it.

## 1.14
- Choose the dock icon for each Stack (KDE icon picker), or keep it automatic.

## 1.13
- New files get a dot, and the dock icon shows how many arrived since the stack was last closed. Can be turned off.
- Right-clicking a folder no longer lists the default file manager twice.

## 1.12
- Type to filter: start typing with the stack open to show only matching files.

## 1.11
- Select several files (Ctrl-click, Shift-click, Ctrl+A) and drag or right-click them together.

## 1.10
- Right-click menu on files and folders: Open, Open With, Show in file manager, Rename, Copy Location, Move to Bin.

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
