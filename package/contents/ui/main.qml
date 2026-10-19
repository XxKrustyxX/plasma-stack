import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtCore
import Qt.labs.folderlistmodel
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.extras as PlasmaExtras
import org.kde.draganddrop as DragDrop
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // Empty setting = the Downloads folder, same as a fresh macOS dock
    readonly property url folderUrl: {
        const f = Plasmoid.configuration.folder;
        if (!f)
            return StandardPaths.writableLocation(StandardPaths.DownloadLocation);
        return f.startsWith("file:") ? f : "file://" + f;
    }
    readonly property string folderName: decodeURIComponent(folderUrl.toString().replace(/\/$/, "").split("/").pop())
    readonly property int maxItems: Math.max(1, Plasmoid.configuration.maxItems)

    // Fan geometry
    readonly property int iconSize: Kirigami.Units.iconSizes.large
    readonly property int rowHeight: iconSize + Kirigami.Units.smallSpacing * 3
    readonly property real radius: 2000
    readonly property int labelWidth: Kirigami.Units.gridUnit * 13

    property var allEntries: []    // snapshot of the folder taken each time the stack opens
    // Open as: 0 = fan, 1 = grid, 2 = automatic (fan unless there are more files than fit)
    property bool showGrid: false

    // Subfolders opened inside the grid, innermost last, as { name, url }. Empty = the stack's own folder.
    property var browsePath: []
    property var subEntries: []    // contents of the innermost one
    property var parentLists: []   // contents of each folder behind the innermost one, outermost first
    onSubEntriesChanged: requestThumbs(subEntries)
    readonly property bool browsing: browsePath.length > 0
    readonly property var gridEntries: browsing ? subEntries : allEntries
    readonly property url gridFolderUrl: browsing ? browsePath[browsePath.length - 1].url : folderUrl
    readonly property string gridFolderName: browsing ? browsePath[browsePath.length - 1].name : folderName
    // Subfolders in the grid: 0 = open in place with a back button, 1 = stack on top of the folder they came from
    readonly property bool stackedFolders: Plasmoid.configuration.subfolderMode === 1
    // Fans on screen, oldest first: just the one, or with "Stacked on top" one per folder opened
    readonly property var fanLevels: (stackedFolders ? parentLists : []).concat([gridEntries])
    property real pushProgress: 1  // 0 → 1 as a newly stacked folder slides into place
    property real progress: 0      // 0 = tucked into the dock, 1 = fully fanned out
    property double lastClosed: 0
    property bool dragging: false  // a file is being dragged out; keep the popup alive until it's dropped

    // The dock icon is shown as-is; the fan is our own popup, not a standard expanded view
    preferredRepresentation: fullRepresentation

    FolderListModel {
        id: folderModel
        folder: root.folderUrl
        showDirs: true
        showDirsFirst: false
        showDotAndDotDot: false
        showHidden: false
        sortField: Plasmoid.configuration.sortMode === 1 ? FolderListModel.Name : FolderListModel.Time
    }

    function folderIcon() {
        switch (folderName) {
        case "Downloads": return "folder-download";
        case "Documents": return "folder-documents";
        case "Pictures": return "folder-pictures";
        case "Music": return "folder-music";
        case "Videos": return "folder-videos";
        case "Desktop": return "user-desktop";
        default: return "folder";
        }
    }

    function isImage(suffix) {
        return ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif", "heic"].indexOf(suffix) >= 0;
    }

    function iconFor(entry) {
        if (entry.isDir)
            return "folder";
        const s = entry.suffix;
        const map = {
            "pdf": "application-pdf",
            "png": "image-x-generic", "jpg": "image-x-generic", "jpeg": "image-x-generic", "gif": "image-x-generic",
            "webp": "image-x-generic", "bmp": "image-x-generic", "svg": "image-x-generic", "avif": "image-x-generic",
            "heic": "image-x-generic",
            "doc": "x-office-document", "docx": "x-office-document", "odt": "x-office-document", "rtf": "x-office-document",
            "xls": "x-office-spreadsheet", "xlsx": "x-office-spreadsheet", "ods": "x-office-spreadsheet", "csv": "x-office-spreadsheet",
            "ppt": "x-office-presentation", "pptx": "x-office-presentation", "odp": "x-office-presentation",
            "zip": "package-x-generic", "tar": "package-x-generic", "gz": "package-x-generic", "xz": "package-x-generic",
            "7z": "package-x-generic", "rar": "package-x-generic", "bz2": "package-x-generic", "zst": "package-x-generic",
            "exe": "application-x-ms-dos-executable", "msi": "application-x-ms-dos-executable",
            "iso": "application-x-cd-image", "img": "application-x-cd-image", "dmg": "application-x-cd-image",
            "rpm": "application-x-rpm", "deb": "application-x-deb", "appimage": "application-x-executable",
            "mp3": "audio-x-generic", "wav": "audio-x-generic", "flac": "audio-x-generic", "ogg": "audio-x-generic", "m4a": "audio-x-generic",
            "mp4": "video-x-generic", "mkv": "video-x-generic", "mov": "video-x-generic", "webm": "video-x-generic", "avi": "video-x-generic",
            "txt": "text-x-generic", "md": "text-x-generic", "log": "text-x-generic",
            "html": "text-html", "htm": "text-html", "json": "application-json",
            "py": "text-x-python", "sh": "application-x-shellscript"
        };
        return map[s] || "unknown";
    }

    // Endings browsers give a file while it's still downloading (Firefox, Chrome/Edge/Brave, Opera)
    readonly property var partialEndings: ["part", "crdownload", "opdownload"]

    function lastSuffix(name) {
        const dot = name.lastIndexOf(".");
        return dot > 0 ? name.slice(dot + 1).toLowerCase() : "";
    }

    // The real names of the downloads still in progress in a folder
    function downloadsIn(model) {
        const names = [];
        for (let i = 0; i < model.count; i++) {
            const name = model.get(i, "fileName");
            if (partialEndings.indexOf(lastSuffix(name)) >= 0)
                names.push(name.slice(0, name.lastIndexOf(".")));
        }
        return names;
    }

    function readFolder(model) {
        const downloading = downloadsIn(model);
        const list = [];
        for (let i = 0; i < model.count; i++) {
            let name = model.get(i, "fileName");
            const isDir = model.get(i, "fileIsDir");
            const partial = !isDir && partialEndings.indexOf(lastSuffix(name)) >= 0;
            if (partial)
                name = name.slice(0, name.lastIndexOf("."));   // show "report.pdf", not "report.pdf.part"
            else if (!isDir && downloading.indexOf(name) >= 0)
                continue;   // Firefox's empty placeholder for a download in progress
            list.push({
                name: name,
                url: model.get(i, "fileUrl"),
                path: model.get(i, "filePath"),
                isDir: isDir,
                suffix: lastSuffix(name),   // "tar.gz" -> "gz"
                size: model.get(i, "fileSize"),
                downloading: partial
            });
        }
        return list;
    }

    // ---- Previews (PDF pages, video frames, album art, office documents), made by contents/code/thumbs.py.
    // Ones Dolphin has already made are reused; the rest are made in the background the first time they're shown.
    property var thumbs: ({})      // file url -> preview url
    property var thumbJobs: ({})   // job id -> urls asked about
    readonly property var previewSuffixes: ["pdf", "mp4", "mkv", "mov", "webm", "avi", "m4v", "wmv", "mpg", "mpeg",
        "mp3", "flac", "m4a", "ogg", "opus", "aac", "wav",
        "odt", "ods", "odp", "odg", "ott", "ots", "otp", "doc", "docx", "xls", "xlsx", "ppt", "pptx"]

    function requestThumbs(list) {
        if (!Plasmoid.configuration.showPreviews)
            return;
        const urls = list.filter(e => !e.isDir && !e.downloading && previewSuffixes.indexOf(e.suffix) >= 0
                                      && !(e.url.toString() in thumbs))
            .slice(0, 300)
            .map(e => e.url.toString());
        if (urls.length > 0)
            runThumbs("lookup", urls);
    }

    function runThumbs(mode, urls) {
        const id = `${mode}-${Date.now()}-${Math.floor(Math.random() * 1e6)}`;
        thumbJobs[id] = urls;
        const args = urls.map(u => shellQuote(u)).join(" ");
        runner.connectSource(`python3 -I ${shellQuote(scriptPath("thumbs.py"))} ${mode} ${args} # thumbs ${id}`);
    }

    function thumbsDone(id, stdout) {
        const found = Object.assign({}, thumbs);
        for (const line of stdout.split("\n")) {
            const tab = line.indexOf("\t");
            if (tab > 0)
                found[line.slice(0, tab)] = line.slice(tab + 1);
        }
        thumbs = found;
        const asked = thumbJobs[id] || [];
        delete thumbJobs[id];
        // Anything the quick look-up didn't find gets made now
        if (id.startsWith("lookup-")) {
            const missing = asked.filter(u => !(u in found));
            if (missing.length > 0)
                runThumbs("make", missing);
        }
    }

    // ---- Downloads: the dock icon shows a bar while something is downloading and bounces when it finishes
    signal downloadFinished()
    property var activeDownloads: []   // real names of downloads in progress in the stack's folder
    property var downloadSizes: ({})   // path of a download in progress -> bytes so far

    function folderChanged() {
        const now = downloadsIn(folderModel);
        const names = [];
        for (let i = 0; i < folderModel.count; i++)
            names.push(folderModel.get(i, "fileName"));
        // Gone from the in-progress list and the finished file is there = a download just finished
        const finished = activeDownloads.some(n => now.indexOf(n) < 0 && names.indexOf(n) >= 0);
        activeDownloads = now;
        if (finished && Plasmoid.configuration.bounceOnDownload)
            downloadFinished();
        // Keep an open stack up to date (a download finishing turns into a normal file)
        if (popupOpen && !browsing) {
            allEntries = readFolder(folderModel);
            requestThumbs(allEntries);
        }
    }

    Connections {
        target: folderModel
        function onRowsInserted() { Qt.callLater(root.folderChanged) }
        function onRowsRemoved() { Qt.callLater(root.folderChanged) }
        function onDataChanged() { Qt.callLater(root.folderChanged) }   // renames like "x.crdownload" -> "x"
        function onModelReset() { Qt.callLater(root.folderChanged) }
        function onStatusChanged() { Qt.callLater(root.folderChanged) }
    }

    function sizeText(entry) {
        const bytes = entry.path in downloadSizes ? downloadSizes[entry.path] : entry.size;
        return Qt.locale().formattedDataSize(bytes, 1);
    }

    // While an open stack shows downloads in progress, update how much has come in every second
    Timer {
        interval: 1000
        repeat: true
        running: root.popupOpen && root.gridEntries.some(e => e.downloading)
        onTriggered: {
            const paths = root.gridEntries.filter(e => e.downloading).map(e => root.shellQuote(e.path)).join(" ");
            runner.connectSource(`stat -c '%s %n' -- ${paths} # download-sizes ${Date.now()}`);
        }
    }

    function openFan() {
        const list = readFolder(folderModel);
        lookUpFileManager();
        browsePath = [];
        subEntries = [];
        parentLists = [];
        const mode = Plasmoid.configuration.viewMode;
        showGrid = mode === 1 || (mode === 2 && list.length > maxItems);
        allEntries = list;
        requestThumbs(list);
        progress = 0;
        fanLoader.active = true;
        fan.visualParent = dockIcon;
        fan.visible = true;
        fan.requestActivate();
        openAnim.restart();
    }

    function enterFolder(entry) {
        parentLists = parentLists.concat([gridEntries]);
        subEntries = [];
        browsePath = browsePath.concat([{ name: entry.name, url: entry.url }]);
        if (stackedFolders)
            pushAnim.restart();
    }

    // Closes every folder stacked in front of the given level (0 = the stack's own folder)
    function backTo(level) {
        parentLists = parentLists.slice(0, level);
        subEntries = [];
        browsePath = browsePath.slice(0, level);
    }

    NumberAnimation {
        id: pushAnim
        target: root
        property: "pushProgress"
        from: 0; to: 1
        duration: 180
        easing.type: Easing.OutCubic
    }

    function goBack() {
        parentLists = parentLists.slice(0, -1);
        subEntries = [];
        browsePath = browsePath.slice(0, -1);
    }

    // Reads whichever subfolder the grid is showing
    FolderListModel {
        id: browseModel
        folder: root.browsing ? root.gridFolderUrl : ""
        showDirs: true
        showDirsFirst: false
        showDotAndDotDot: false
        showHidden: false
        sortField: folderModel.sortField
        onStatusChanged: if (status === FolderListModel.Ready && root.browsing) root.subEntries = root.readFolder(browseModel)
        // (previews for a subfolder are asked for in onSubEntriesChanged)
        onCountChanged: if (status === FolderListModel.Ready && root.browsing) root.subEntries = root.readFolder(browseModel)
    }

    function closeFan() {
        openAnim.stop();
        if (fan)
            fan.visible = false;
    }

    function shellQuote(text) {
        return "'" + String(text).replace(/'/g, "'\\''") + "'";
    }

    property var droppedUrls: []   // waiting for a choice from the Move / Copy menu

    // Files dropped on the dock icon go into the folder (see contents/code/drop.sh). mode is "move" or "copy".
    // Path of one of our helper scripts in contents/code
    function scriptPath(name) {
        return decodeURIComponent(Qt.resolvedUrl("../code/" + name).toString().replace(/^file:\/\//, ""));
    }

    function receive(urls, mode) {
        const script = scriptPath("drop.sh");
        const dest = decodeURIComponent(folderUrl.toString().replace(/^file:\/\//, ""));
        const args = Array.from(urls, u => shellQuote(u.toString())).join(" ");
        // The timestamp keeps two identical drops from looking like the same command to the runner
        runner.connectSource(`bash ${shellQuote(script)} ${mode} ${shellQuote(dest)} ${args} # ${Date.now()}`);
    }

    // The dock panel opens a "new widget goes here" gap while files are dragged over it, and only
    // closes it when the drag leaves the panel or lands on the panel itself. Files that land on us
    // never tell it, so close the gap ourselves by giving the panel's drop area its "drag left" signal.
    function closePanelGap() {
        for (let item = root.parent; item; item = item.parent) {
            if (item.marginAreasEnabled !== undefined && typeof item.dragLeave === "function") {
                item.dragLeave(null);
                return;
            }
        }
    }

    // Like dropping onto a folder in Dolphin: Shift moves, Ctrl copies, otherwise ask
    function handleDrop(urls, modifiers) {
        const inFolder = folderUrl.toString().replace(/\/$/, "") + "/";
        // Files dragged out of this stack and straight back in are already where they belong
        const incoming = Array.from(urls, u => u.toString())
            .filter(u => !(u.startsWith(inFolder) && u.slice(inFolder.length).indexOf("/") < 0));
        if (incoming.length === 0)
            return;
        if (modifiers & Qt.ShiftModifier) {
            receive(incoming, "move");
        } else if (modifiers & Qt.ControlModifier) {
            receive(incoming, "copy");
        } else {
            droppedUrls = incoming;
            moveItem.enabled = incoming.every(u => u.startsWith("file:"));   // web links can only be downloaded
            // Opened after the drop has finished, so the drag doesn't swallow the menu
            Qt.callLater(() => dropMenu.openRelative());
        }
    }

    PlasmaExtras.Menu {
        id: dropMenu

        PlasmaExtras.MenuItem {
            id: moveItem
            text: i18n("&Move Here")
            icon: "go-jump"
            onClicked: root.receive(root.droppedUrls, "move")
        }
        PlasmaExtras.MenuItem {
            text: i18n("&Copy Here")
            icon: "edit-copy"
            onClicked: root.receive(root.droppedUrls, "copy")
        }
        PlasmaExtras.MenuItem {
            separator: true
        }
        PlasmaExtras.MenuItem {
            text: i18n("C&ancel")
            icon: "process-stop"
        }
    }

    // Name of the default file manager for the "Open in …" buttons (Dolphin, COSMIC Files, …).
    // Looked up again each time the stack opens, in case the default has changed.
    property string fileManagerName: ""
    readonly property string fileManagerLabel: fileManagerName || i18n("File Manager")

    function lookUpFileManager() {
        runner.connectSource(`bash ${shellQuote(scriptPath("file-manager-name.sh"))} # file-manager ${Date.now()}`);
    }

    Component.onCompleted: lookUpFileManager()

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (source, data) => {
            if (source.indexOf("# file-manager ") >= 0) {
                root.fileManagerName = data.stdout.trim();
            } else if (source.indexOf("# thumbs ") >= 0) {
                root.thumbsDone(source.slice(source.indexOf("# thumbs ") + 9), data.stdout);
            } else if (source.indexOf("# download-sizes ") >= 0) {
                const sizes = {};
                for (const line of data.stdout.split("\n")) {
                    const space = line.indexOf(" ");
                    if (space > 0)
                        sizes[line.slice(space + 1)] = Number(line.slice(0, space));
                }
                root.downloadSizes = sizes;
            }
            disconnectSource(source);
        }
    }

    function openUrl(url) {
        closeFan();
        Qt.openUrlExternally(url);
    }

    // A file's picture: a preview for images, otherwise an icon for its type. No entry = the file manager.
    component FileIcon: Item {
        id: fileIcon
        property var entry: null
        // With "Show previews" off, every file just gets its icon
        readonly property bool previewsOn: Plasmoid.configuration.showPreviews
        readonly property string thumb: previewsOn && entry !== null && !entry.downloading ? (root.thumbs[entry.url.toString()] || "") : ""
        readonly property bool preview: previewsOn && entry !== null && !entry.downloading && (thumb !== "" || root.isImage(entry.suffix))

        // A made preview (PDF page, video frame, ...) gets a thin edge so white pages don't vanish
        Rectangle {
            visible: fileIcon.thumb !== "" && picture.status === Image.Ready
            anchors.centerIn: picture
            width: picture.paintedWidth + 2
            height: picture.paintedHeight + 2
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.25)
        }

        Image {
            id: picture
            anchors.fill: parent
            visible: fileIcon.preview
            source: visible ? (fileIcon.thumb || fileIcon.entry.url) : ""
            sourceSize: Qt.size(parent.width * 2, parent.height * 2)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
        }

        Kirigami.Icon {
            anchors.fill: parent
            visible: !fileIcon.preview
            source: fileIcon.entry === null ? "system-file-manager" : root.iconFor(fileIcon.entry)
            fallback: "unknown"
            // Downloads still coming in are faded, with a pulsing arrow badge
            opacity: fileIcon.entry !== null && fileIcon.entry.downloading ? 0.45 : 1
        }

        Rectangle {
            visible: fileIcon.entry !== null && fileIcon.entry.downloading
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: parent.width * 0.42
            height: width
            radius: width / 2
            color: Kirigami.Theme.highlightColor

            Kirigami.Icon {
                anchors.fill: parent
                anchors.margins: parent.width * 0.18
                source: "go-down"
                color: "white"
                isMask: true
            }

            SequentialAnimation on opacity {
                running: parent.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.5; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
            }
        }
    }

    // Lets a file be dragged out to the file manager, the desktop or any app that takes files.
    // Put one inside a MouseArea and point the MouseArea's drag.target at it.
    component FileDrag: Item {
        id: dragItem
        property var entry: null
        property var grab: null    // the picture must stay referenced for its url to stay valid
        property bool active: false
        visible: false
        Drag.active: active && entry !== null && !entry.downloading
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
        Drag.mimeData: entry ? { "text/uri-list": entry.url.toString() } : {}
        Drag.onDragStarted: root.dragging = true
        Drag.onDragFinished: {
            root.dragging = false;
            root.closeFan();
        }

        // Picture under the cursor while dragging
        function prepare(iconItem) {
            iconItem.grabToImage(result => {
                dragItem.grab = result;
                dragItem.Drag.imageSource = result.url;
            });
        }
    }

    NumberAnimation {
        id: openAnim
        target: root
        property: "progress"
        from: 0; to: 1
        duration: 260
        easing.type: Easing.OutCubic
    }

    fullRepresentation: MouseArea {
        id: compact
        hoverEnabled: true
        // Square, the size of the other dock icons
        Layout.minimumWidth: Plasmoid.formFactor === PlasmaCore.Types.Vertical ? 0 : height
        Layout.minimumHeight: Plasmoid.formFactor === PlasmaCore.Types.Vertical ? width : 0
        Component.onCompleted: {
            root.dockIcon = compact;
            dropMenu.visualParent = compact;
        }
        onClicked: {
            folderTip.hideImmediately();
            // A click on the dock icon while the fan is open first closes it via deactivation; don't reopen straight away
            if (root.popupOpen || Date.now() - root.lastClosed < 250)
                root.closeFan();
            else
                root.openFan();
        }

        Kirigami.Icon {
            anchors.fill: parent
            source: root.folderIcon()
            active: compact.containsMouse || dropZone.hovering
            // Swells a little while files are held over it, like the macOS dock
            scale: dropZone.hovering ? 1.15 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }
            transform: Translate { id: bounceShift }
        }

        // Hops twice when a download finishes, like the macOS Downloads stack
        // (kept low: a widget can't draw above the top edge of the dock)
        SequentialAnimation {
            id: bounce
            NumberAnimation { target: bounceShift; property: "y"; to: -compact.height * 0.25; duration: 180; easing.type: Easing.OutQuad }
            NumberAnimation { target: bounceShift; property: "y"; to: 0; duration: 180; easing.type: Easing.InQuad }
            NumberAnimation { target: bounceShift; property: "y"; to: -compact.height * 0.12; duration: 140; easing.type: Easing.OutQuad }
            NumberAnimation { target: bounceShift; property: "y"; to: 0; duration: 140; easing.type: Easing.InQuad }
        }

        Connections {
            target: root
            function onDownloadFinished() { bounce.restart() }
        }

        // Something is downloading into this folder: a bar across the icon with a segment sliding back and forth
        // (browsers don't say how big a download will be, so it can't show a percentage)
        Rectangle {
            id: downloadBar
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.1
            width: parent.width * 0.72
            height: Math.max(4, Math.round(parent.height * 0.11))
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.6)
            border.color: Qt.rgba(1, 1, 1, 0.5)
            visible: root.activeDownloads.length > 0
            clip: true

            Rectangle {
                width: parent.width * 0.4
                height: parent.height
                radius: parent.radius
                color: Kirigami.Theme.highlightColor

                SequentialAnimation on x {
                    running: downloadBar.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: downloadBar.width * 0.6; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { from: downloadBar.width * 0.6; to: 0; duration: 800; easing.type: Easing.InOutSine }
                }
            }
        }

        // Folder name on hover, the same style of tooltip as the app icons on the dock
        PlasmaCore.ToolTipArea {
            id: folderTip
            anchors.fill: parent
            mainText: root.folderName
            location: Plasmoid.location
            active: !root.popupOpen && !root.dragging
        }

        // KDE's own drop area rather than Qt's: it tells the panel to drop its
        // "new widget goes here" gap when we take the files
        DragDrop.DropArea {
            id: dropZone
            property bool hovering: false
            anchors.fill: parent
            preventStealing: true
            onDragEnter: event => {
                hovering = event.mimeData.hasUrls;
                root.closePanelGap();
            }
            onDragLeave: hovering = false
            onDrop: event => {
                hovering = false;
                root.closePanelGap();
                if (!event.mimeData.hasUrls) {
                    event.ignore();
                    return;
                }
                root.handleDrop(event.mimeData.urls, event.modifiers);
                // Report a copy whatever we do, so the app the files came from never deletes its own copy
                event.accept(Qt.CopyAction);
            }
        }
    }

    // The popup (fan or grid) is only built when the stack opens and is thrown away when it closes,
    // so a closed stack costs next to nothing
    property Item dockIcon: null
    readonly property var fan: fanLoader.item
    readonly property bool popupOpen: fan !== null && fan.visible

    Loader {
        id: fanLoader
        active: false
        sourceComponent: PlasmaCore.Dialog {
            location: Plasmoid.location
            type: PlasmaCore.Dialog.PopupMenu
            backgroundHints: PlasmaCore.Dialog.NoBackground
            flags: Qt.WindowStaysOnTopHint
            hideOnWindowDeactivate: !root.dragging
            onVisibleChanged: {
                if (!visible) {
                    root.lastClosed = Date.now();
                    // Not straight away: the window is still in the middle of hiding
                    Qt.callLater(() => fanLoader.active = false);
                }
            }

            mainItem: Item {
                width: root.showGrid ? gridBox.width : canvas.width
                height: root.showGrid ? gridBox.height + gridStack.depth * gridStack.step : canvas.height
                focus: true
                Keys.onEscapePressed: root.closeFan()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Backspace && root.browsing) {
                        root.goBack();
                        event.accepted = true;
                    }
                }

                // Fan: files climb a gentle curve above the dock icon. With "Stacked on top", a folder clicked
                // in the fan gets its own fan; the earlier ones slide right, dim, and go back to their folder when clicked.
                Item {
                    id: canvas
                    visible: !root.showGrid
                    readonly property int depth: root.fanLevels.length - 1
                    readonly property real shift: root.iconSize + Kirigami.Units.largeSpacing * 2
                    // Tallest fan, plus one row at the top for "Open in <file manager>"
                    readonly property int rows: Math.min(root.maxItems, Math.max(...root.fanLevels.map(list => list.length))) + 1
                    readonly property real topAngle: (rows - 0.5) * root.rowHeight / root.radius
                    readonly property real leftExtent: root.iconSize / 2 + Kirigami.Units.smallSpacing + root.labelWidth
                    readonly property real rightExtent: root.radius * (1 - Math.cos(topAngle)) + root.iconSize + depth * shift
                    width: 2 * Math.max(leftExtent, rightExtent) + Kirigami.Units.gridUnit * 2
                    height: root.radius * Math.sin(topAngle) + root.rowHeight + Kirigami.Units.gridUnit

                    Repeater {
                        model: canvas.visible ? root.fanLevels.length : 0

                        delegate: Item {
                            id: fanLayer
                            readonly property int level: index
                            readonly property bool current: level === canvas.depth
                            readonly property var list: root.fanLevels[level] || []
                            readonly property var shown: list.slice(0, root.maxItems)
                            readonly property int hidden: Math.max(0, list.length - root.maxItems)
                            // (While going back, a fan about to be removed can briefly outlive its entry in browsePath)
                            readonly property url folder: level > 0 && root.browsePath[level - 1] ? root.browsePath[level - 1].url : root.folderUrl
                            // A newly opened fan grows out of the dock like the first one
                            readonly property real grow: current && level > 0 ? root.pushProgress : 1

                            width: canvas.width
                            height: canvas.height
                            z: level
                            x: (canvas.depth - level) * canvas.shift
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            opacity: current ? 1 : 0.5

                            Repeater {
                                model: fanLayer.shown.length + 1

                                delegate: Item {
                                    id: row
                                    readonly property bool isMore: index === fanLayer.shown.length
                                    readonly property var entry: isMore ? null : fanLayer.shown[index]
                                    // Bottom row (newest) sits just above the dock, later rows climb the arc and lean
                                    readonly property real angle: (index + 0.5) * root.rowHeight / root.radius * root.progress * fanLayer.grow
                                    readonly property real cx: canvas.width / 2 + root.radius * (1 - Math.cos(angle))
                                    readonly property real cy: canvas.height - root.radius * Math.sin(angle) - root.rowHeight / 2

                                    width: root.labelWidth + Kirigami.Units.smallSpacing + root.iconSize
                                    height: root.rowHeight
                                    x: cx - width + root.iconSize / 2
                                    y: cy - height / 2
                                    opacity: root.progress * fanLayer.grow
                                    transform: Rotation {
                                        origin.x: row.width - root.iconSize / 2
                                        origin.y: row.height / 2
                                        angle: row.angle * 180 / Math.PI
                                    }

                                    MouseArea {
                                        id: hit
                                        // Only the icon and its label are clickable, not the empty space beside the label.
                                        // Fans behind the current one show just their icons.
                                        x: fanLayer.current ? label.x : parent.width - root.iconSize
                                        width: parent.width - x
                                        height: parent.height
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        drag.target: fanLayer.current && !row.isMore ? rowDrag : null
                                        onPressed: if (fanLayer.current && !row.isMore) rowDrag.prepare(icon)
                                        onClicked: {
                                            if (!fanLayer.current)
                                                root.backTo(fanLayer.level);
                                            else if (row.isMore)
                                                root.openUrl(fanLayer.folder);
                                            else if (row.entry.downloading)
                                                return;   // nothing to open until it's finished
                                            else if (row.entry.isDir && root.stackedFolders)
                                                root.enterFolder(row.entry);
                                            else
                                                root.openUrl(row.entry.url);
                                        }

                                        FileDrag {
                                            id: rowDrag
                                            entry: row.entry
                                            active: hit.drag.active
                                        }
                                    }

                                    Rectangle {
                                        id: label
                                        visible: fanLayer.current
                                        anchors.right: icon.left
                                        anchors.rightMargin: Kirigami.Units.smallSpacing
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(root.labelWidth, text.implicitWidth + Kirigami.Units.largeSpacing * 2)
                                        height: text.implicitHeight + Kirigami.Units.smallSpacing * 2
                                        radius: height / 2
                                        color: hit.containsMouse ? Kirigami.Theme.highlightColor : Qt.rgba(0.1, 0.1, 0.1, 0.78)

                                        Text {
                                            id: text
                                            anchors.centerIn: parent
                                            width: parent.width - Kirigami.Units.largeSpacing * 2
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideMiddle
                                            color: "white"
                                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.95
                                            text: row.isMore
                                                ? (fanLayer.hidden > 0 ? i18n("%1 more in %2", fanLayer.hidden, root.fileManagerLabel) : i18n("Open in %1", root.fileManagerLabel))
                                                : row.entry.downloading
                                                    ? i18n("%1 · downloading %2", row.entry.name, root.sizeText(row.entry))
                                                    : row.entry.name
                                        }
                                    }

                                    FileIcon {
                                        id: icon
                                        entry: row.entry
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: root.iconSize
                                        height: root.iconSize
                                        scale: hit.containsMouse ? 1.08 : 1
                                        Behavior on scale { NumberAnimation { duration: 90 } }
                                    }
                                }
                            }
                        }
                    }
                }

                // Stacked folders: the folders you came through peek out above the open one, furthest back on top.
                // Clicking one closes everything in front of it.
                Repeater {
                    id: gridStack
                    readonly property int depth: root.showGrid && root.stackedFolders ? root.browsePath.length : 0
                    readonly property real step: header.height + gridBox.pad * 1.5
                    model: depth

                    delegate: Rectangle {
                        // index 0 = the stack's own folder
                        readonly property int behind: gridStack.depth - index   // how many folders sit in front of it
                        Kirigami.Theme.colorSet: Kirigami.Theme.Window
                        Kirigami.Theme.inherit: false
                        z: 0
                        width: gridBox.width
                        height: gridBox.height
                        y: gridBox.y - behind * gridStack.step
                        // Slightly smaller and darker the further back it is
                        scale: 1 - 0.03 * behind
                        transformOrigin: Item.Top
                        radius: gridBox.radius
                        color: Qt.darker(Kirigami.Theme.backgroundColor, 1 + 0.12 * behind)
                        border.color: gridBox.border.color
                        opacity: root.progress

                        Kirigami.Heading {
                            anchors.top: parent.top
                            anchors.topMargin: gridBox.pad
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - gridBox.pad * 2
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            level: 4
                            opacity: strip.containsMouse ? 1 : 0.65
                            text: index > 0 && root.browsePath[index - 1] ? root.browsePath[index - 1].name : root.folderName
                        }

                        MouseArea {
                            id: strip
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.backTo(index)
                        }
                    }
                }

                // Grid: every file in a rounded box, scrolling when there are lots
                Rectangle {
                    id: gridBox
                    visible: root.showGrid
                    z: 1    // above the stacked folders behind it
                    y: gridStack.depth * gridStack.step
                    Kirigami.Theme.colorSet: Kirigami.Theme.Window
                    Kirigami.Theme.inherit: false

                    readonly property int pad: Kirigami.Units.largeSpacing
                    readonly property int cellWidth: Kirigami.Units.gridUnit * 6
                    readonly property int cellHeight: root.iconSize + Kirigami.Units.gridUnit * 3
                    // Never smaller than the top-level view, so the box doesn't jump about while browsing subfolders
                    readonly property int columns: Math.max(3, Math.min(5, Math.max(root.allEntries.length, root.gridEntries.length)))
                    readonly property int visibleRows: Math.max(1, Math.min(4, Math.ceil(Math.max(root.allEntries.length, root.gridEntries.length) / columns)))

                    width: columns * cellWidth + pad * 2
                    height: header.height + visibleRows * cellHeight + footer.height + pad * 4
                    radius: Kirigami.Units.cornerRadius * 3
                    color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.96)
                    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                    // Grows up out of the dock icon
                    opacity: root.progress * (root.stackedFolders ? root.pushProgress : 1)
                    scale: 0.85 + 0.15 * root.progress
                    transformOrigin: Item.Bottom
                    // A newly stacked folder slides up into place
                    transform: Translate { y: root.stackedFolders ? (1 - root.pushProgress) * gridStack.step : 0 }

                    // Folder name, with a back button once you've gone into a subfolder (unless they're stacked)
                    Item {
                        id: header
                        anchors.top: parent.top
                        anchors.topMargin: gridBox.pad
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: gridBox.pad
                        anchors.rightMargin: gridBox.pad
                        height: Math.max(title.implicitHeight, backButton.implicitHeight)

                        QQC2.ToolButton {
                            id: backButton
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, parent.width / 3)
                            visible: root.browsing && !root.stackedFolders
                            icon.name: "go-previous"
                            text: root.browsePath.length > 1 ? root.browsePath[root.browsePath.length - 2].name : root.folderName
                            onClicked: root.goBack()
                        }

                        Kirigami.Heading {
                            id: title
                            anchors.centerIn: parent
                            width: parent.width - (backButton.visible ? backButton.width * 2 + Kirigami.Units.smallSpacing * 2 : 0)
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            level: 4
                            text: root.gridFolderName
                        }
                    }

                    GridView {
                        id: grid
                        anchors.top: header.bottom
                        anchors.topMargin: gridBox.pad
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: gridBox.columns * gridBox.cellWidth
                        height: gridBox.visibleRows * gridBox.cellHeight
                        cellWidth: gridBox.cellWidth
                        cellHeight: gridBox.cellHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: gridBox.visible ? root.gridEntries : []
                        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                        delegate: MouseArea {
                            id: cell
                            width: gridBox.cellWidth
                            height: gridBox.cellHeight
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            drag.target: cellDrag
                            onPressed: cellDrag.prepare(cellIcon)
                            // Folders open right here in the grid, like macOS
                            onClicked: {
                                if (modelData.downloading)
                                    return;   // nothing to open until it's finished
                                modelData.isDir ? root.enterFolder(modelData) : root.openUrl(modelData.url);
                            }

                            FileDrag {
                                id: cellDrag
                                entry: modelData
                                active: cell.drag.active
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: Kirigami.Units.cornerRadius
                                color: Kirigami.Theme.highlightColor
                                opacity: cell.containsMouse ? 0.25 : 0
                            }

                            FileIcon {
                                id: cellIcon
                                entry: modelData
                                anchors.top: parent.top
                                anchors.topMargin: Kirigami.Units.smallSpacing
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: root.iconSize
                                height: root.iconSize
                            }

                            QQC2.Label {
                                anchors.top: cellIcon.bottom
                                anchors.topMargin: Kirigami.Units.smallSpacing
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - Kirigami.Units.smallSpacing * 2
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                maximumLineCount: modelData.downloading ? 3 : 2
                                elide: Text.ElideRight
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                text: modelData.downloading
                                    ? modelData.name + "\n" + i18n("Downloading… %1", root.sizeText(modelData))
                                    : modelData.name
                            }
                        }

                        QQC2.Label {
                            anchors.centerIn: parent
                            visible: root.gridEntries.length === 0 && (!root.browsing || browseModel.status === FolderListModel.Ready)
                            opacity: 0.6
                            text: i18n("This folder is empty")
                        }
                    }

                    QQC2.Button {
                        id: footer
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: gridBox.pad
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon.name: "system-file-manager"
                        text: i18n("Open in %1", root.fileManagerLabel)
                        onClicked: root.openUrl(root.gridFolderUrl)
                    }
                }
            }
        }
    }
}
