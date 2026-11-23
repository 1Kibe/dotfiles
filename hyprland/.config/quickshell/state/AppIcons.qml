pragma Singleton

import QtQuick
import Quickshell

// An app's icon from its window's class, for the minimized strip, its
// preview and the overview's cards: the icon theme by the class, then by
// the class in lower case, then the icon its desktop entry names
// (DesktopEntries.heuristicLookup: Spotify's windows say "Spotify", its
// icon is "spotify-launcher"). Only what Quickshell.iconPath resolves in
// the icon theme (it checks the name exists); an Icon= that is a file path
// is taken only under /usr/share/pixmaps or /usr/share/icons, never from a
// home folder. "" when nothing is found (the generic icon). The desktop
// entries are read after the start: icon() runs again when they arrive.
Singleton {
    id: root

    // How many desktop entries are known: a binding calling icon() reads it,
    // so it is worked out again when the entries arrive
    readonly property int known: DesktopEntries.applications.values.length

    readonly property var namePattern: /^[A-Za-z0-9][A-Za-z0-9._+-]{0,127}$/
    readonly property var filePattern: /^\/usr\/share\/(pixmaps|icons)\/[A-Za-z0-9._+\/-]+\.(png|svg|xpm)$/

    function icon(cls) {
        // Read here so a binding calling icon() follows the entries
        root.known
        const c = String(cls || "")
        if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/.test(c))
            return ""
        const own = Quickshell.iconPath(c, true) || Quickshell.iconPath(c.toLowerCase(), true)
        if (own !== "")
            return own
        const entry = DesktopEntries.heuristicLookup(c)
        const name = entry ? String(entry.icon || "") : ""
        if (name.startsWith("/"))
            return fromFile(name)
        return root.namePattern.test(name) ? Quickshell.iconPath(name, true) : ""
    }
    // A desktop entry's Icon= that is a file: only an image under
    // /usr/share/pixmaps or /usr/share/icons, no ".." in the way
    function fromFile(path) {
        const p = String(path || "")
        return root.filePattern.test(p) && !p.split("/").includes("..") ? "file://" + p : ""
    }
}
