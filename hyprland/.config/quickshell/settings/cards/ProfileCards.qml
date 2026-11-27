import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.state
import "../ui"
import "../schema.js" as Schema
import "../profile.js" as Profile

// Configurações → Perfis: one poster per profile (the Padrão first, then the
// owner's in their order) and, last, "Novo perfil" (from how things are
// now). A click on a card applies it; the Padrão's card is going back to the
// repo's defaults. When today's values differ from the active profile's, a
// banner above the cards says what changed and offers to update it (never
// the Padrão, which is not written), to save as a new one or to discard (the
// active one applied again). Each own card has a "⋯" menu: Renomear (the
// name under the card becomes a field), Duplicar and Apagar (two clicks);
// its actions act on that card's id, kept when the menu opened, and the menu
// closes with Esc, a click outside or the list changing. Dragging an own
// card onto another's place reorders them (Ctrl+arrows with the keyboard);
// the arrows apply the neighbor. While the folders are read or written the
// buttons wait, with a word saying so; what did not work stays written until
// the next action. Nothing is written with the screen locked.
Item {
    id: root

    activeFocusOnTab: true

    readonly property var profiles: ProfileStore.profiles
    readonly property bool locked: LockState.locked || LockState.wanted
    readonly property bool canAct: !locked && !ProfileStore.busy && ProfileStore.ready
    readonly property bool full: Object.keys(ProfileStore.found).length >= Profile.MAX
    readonly property var activeProfile: ProfileStore.get(ProfileStore.active) ?? ProfileStore.padrao
    readonly property bool activeOwn: activeProfile !== null && !activeProfile.builtin
    readonly property string busyText: "Espere: os perfis ainda estão sendo lidos ou gravados."
    property string notice: ""

    // ── The banner: what changed since the active one was applied ──
    readonly property bool bannerShown: ProfileStore.dirty
    readonly property var changed: activeProfile !== null && SettingsStore.ready
        ? Profile.changedGroups(Schema, ProfileStore.keys.concat(["wallpaper"]), ProfileStore.wanted(activeProfile),
                                Object.assign({}, SettingsStore.values, {
                                    wallpaper: ProfileStore.samePath(SettingsStore.values.wallpaper, ProfileStore.wanted(activeProfile).wallpaper)
                                               ? ProfileStore.wanted(activeProfile).wallpaper : SettingsStore.values.wallpaper }))
        : []
    readonly property string changedText: Profile.groupsText(changed)

    // ── A name asked: "" | "new" (a new profile, from the banner's Salvar
    // como novo) | "plus" (a new profile, in the "Novo perfil" card) |
    // "rename" (under a card, for renamingId) ──
    property string naming: ""
    property string renamingId: ""
    property bool nameBad: false

    // ── The "⋯" menu: the card it is for (kept when it opened) ──
    property string menuId: ""
    property bool armed: false
    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = false
    }
    // (where: the card's top right corner, in this item, kept when it opens)
    property real menuX: 0
    property real menuY: 0
    function openMenu(id, from) {
        if (ProfileStore.get(id) === null || ProfileStore.get(id).builtin)
            return
        notice = canAct ? "" : (locked ? "" : busyText)
        armed = false
        disarm.stop()
        if (from) {
            const pt = from.mapToItem(root, from.width, from.height)
            menuX = pt.x
            menuY = pt.y
        }
        menuId = id
        forceActiveFocus()
    }
    function closeMenu() {
        menuId = ""
        armed = false
        disarm.stop()
    }
    // (the list changing closes the menu and the rename field: they were for
    // the list as it was)
    onProfilesChanged: {
        closeMenu()
        if (naming === "rename")
            cancelNaming()
    }
    // 1: the page losing the keyboard (a click elsewhere in the panel) or
    // the panel scrolling closes the menu
    onActiveFocusChanged: {
        if (!activeFocus)
            closeMenu()
    }
    property Item flick: null
    Component.onCompleted: {
        for (let p = parent; p; p = p.parent)
            if (p.contentY !== undefined && p.flicking !== undefined) {
                flick = p
                break
            }
    }
    Connections {
        target: root.flick
        ignoreUnknownSignals: true
        function onContentYChanged() {
            root.closeMenu()
        }
    }
    // The menu's items, on the id it opened for
    function menuAction(what) {
        const id = menuId
        if (id === "" || ProfileStore.get(id) === null) {
            closeMenu()
            return false
        }
        if (what === "rename") {
            closeMenu()
            startRename(id)
            return true
        }
        if (what === "duplicate") {
            closeMenu()
            return act(() => ProfileStore.duplicate(id))
        }
        if (what === "export" || what === "exportbare") {
            closeMenu()
            exportPicture = what === "export"
            return act(() => ProfileStore.exportProfile(id, what === "export"))
        }
        if (what === "remove") {
            if (!armed) {
                armed = true
                disarm.restart()
                return false
            }
            closeMenu()
            return act(() => ProfileStore.remove(id))
        }
        return false
    }

    property bool exportPicture: true
    Connections {
        target: ProfileStore
        function onFailed(message) {
            root.notice = message
        }
        function onDone(what, id) {
            if (what === "create" && root.adopting) {
                root.adopting = false
                ProfileStore.adoptActive(id)
            }
            if (what === "export" && ProfileStore.lastExport !== "")
                root.notice = `Exportado para ${ProfileStore.exportsShown}/${ProfileStore.lastExport}: `
                              + (ProfileStore.lastExportPicture ? "o nome e a imagem vão junto."
                                 : root.exportPicture ? "o nome vai junto; a imagem não pôde ir." : "o nome vai junto, sem a imagem.")
            else if (what === "importdone") {
                root.notice = ProfileStore.importNote !== ""
                    ? `Importado, sem a imagem: ${ProfileStore.importNote}. Clique no cartão para aplicar.`
                    : "Importado: clique no cartão para aplicar."
                ProfileStore.listImports()
            }
        }
    }
    // The export folder's list, open below the cards
    property bool importOpen: false
    function toggleImports() {
        notice = ""
        importOpen = !importOpen
        if (importOpen && !ProfileStore.listImports() && ProfileStore.exportsRel === "")
            notice = "A pasta Documentos não foi encontrada: não dá para importar."
    }
    function importFolder(folder) {
        return act(() => ProfileStore.importFolder(folder))
    }

    // An action: never silent (busy, or the store refused without saying why)
    function act(fn) {
        notice = ""
        if (!canAct) {
            if (!locked)
                notice = busyText
            return false
        }
        const ok = fn() === true
        if (!ok && notice === "")
            notice = "Não deu para fazer isso agora: nada mudou."
        return ok
    }
    function apply(p) {
        notice = ""
        closeMenu()
        if (locked || p === null)
            return
        if (!ProfileStore.apply(p.id, { fromCursor: true }) && notice === "")
            notice = "Não deu para aplicar o perfil: nada mudou."
    }
    // The banner's buttons
    function updateActive() {
        if (!activeOwn)
            return false
        return act(() => ProfileStore.saveActive())
    }
    function discard() {
        apply(activeProfile)
    }
    // where: "new" (the banner) or "plus" (the "Novo perfil" card)
    function startNew(where) {
        if (!canAct || full) {
            if (!canAct && !locked)
                notice = busyText
            return
        }
        closeMenu()
        naming = where === "plus" ? "plus" : "new"
        nameBad = false
        const f = naming === "plus" ? plusField : newField
        f.input.text = ""
        f.input.forceActiveFocus()
    }
    // the next create is today's values: it becomes the active one
    property bool adopting: false
    function startRename(id) {
        const p = ProfileStore.get(id)
        if (!canAct || p === null || p.builtin)
            return
        naming = "rename"
        renamingId = id
        nameBad = false
        renameText = p.nome
    }
    property string renameText: ""
    // A name given: checked first; the field closes only once it is written
    function finishNaming(text) {
        if (naming === "")
            return false
        if (!Profile.checkName(text)) {
            nameBad = true
            return false
        }
        const kind = naming, id = renamingId
        nameBad = false
        const creating = kind === "new" || kind === "plus"
        const ok = act(() => creating ? ProfileStore.save(text) : ProfileStore.rename(id, text))
        if (ok) {
            adopting = creating
            naming = ""
        }
        return ok
    }
    function cancelNaming() {
        naming = ""
        nameBad = false
    }
    // Reorder: an own profile to a place among the owner's (0 = right after
    // the Padrão)
    function moveTo(id, place) {
        act(() => ProfileStore.move(id, place))
    }

    readonly property int columns: 3
    readonly property real cellWidth: Math.max(110, Math.floor((width - (columns - 1) * grid.spacing) / columns))
    readonly property int activeIndex: profiles.findIndex(p => p.id === ProfileStore.active)
    // The arrows: the neighbor applied; with Ctrl, the active one moved
    // (nothing while a name is being typed or the menu is open)
    function arrow(dir, ctrl) {
        if (naming !== "" || menuId !== "")
            return
        if (ctrl) {
            if (dir < 0 && activeIndex > 1)
                moveTo(ProfileStore.active, activeIndex - 2)
            else if (dir > 0 && activeIndex >= 1 && activeIndex < profiles.length - 1)
                moveTo(ProfileStore.active, activeIndex)
            return
        }
        const i = activeIndex + dir
        if (i >= 0 && i < profiles.length)
            apply(profiles[i])
    }
    Keys.onLeftPressed: event => arrow(-1, (event.modifiers & Qt.ControlModifier) !== 0)
    Keys.onRightPressed: event => arrow(1, (event.modifiers & Qt.ControlModifier) !== 0)
    Keys.onEscapePressed: event => {
        if (menuId !== "") {
            closeMenu()
            event.accepted = true
        } else {
            event.accepted = false
        }
    }

    implicitHeight: column.implicitHeight
    Column {
        id: column
        width: parent.width
        spacing: 12

        // ── The banner ──
        Rectangle {
            id: banner
            visible: root.bannerShown
            width: parent.width
            height: bannerRow.implicitHeight + 20
            radius: Theme.radius
            color: Theme.bg1
            Flow {
                id: bannerRow
                x: 12
                y: 10
                width: parent.width - 24
                spacing: 10
                Row {
                    spacing: 10
                    width: Math.max(160, bannerRow.width - (root.naming === "new" ? newBox.width : buttons.width) - 12)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8; height: 8; radius: 4
                        color: Theme.yellow
                    }
                    // "Você mudou o <nome, in bold> desde que aplicou: <list>"
                    Flow {
                        id: bannerText
                        width: parent.width - 18
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Repeater {
                            model: [{ t: "Você mudou o", b: false }, { t: root.activeProfile ? root.activeProfile.nome : "", b: true },
                                    { t: "desde que aplicou:", b: false }, { t: root.changedText, b: false }]
                            Text {
                                required property var modelData
                                text: modelData.t
                                textFormat: Text.PlainText
                                color: Theme.text
                                font.family: Theme.fontPanels
                                font.bold: modelData.b
                                font.pointSize: Theme.fontSize - 1
                            }
                        }
                    }
                }
                // Atualizar, Salvar como novo, Descartar
                Row {
                    id: buttons
                    visible: root.naming !== "new"
                    spacing: 8
                    enabled: root.canAct
                    opacity: enabled ? 1 : 0.5
                    Button {
                        visible: root.activeOwn
                        text: `Atualizar “${root.activeProfile ? root.activeProfile.nome : ""}”`
                        primary: true
                        onClicked: root.updateActive()
                    }
                    Button {
                        text: "Salvar como novo"
                        outline: true
                        visible: !root.full
                        onClicked: root.startNew("new")
                    }
                    Button {
                        text: "Descartar"
                        flat: true
                        onClicked: root.discard()
                    }
                }
                // The new profile's name
                Row {
                    id: newBox
                    visible: root.naming === "new"
                    spacing: 8
                    Field {
                        id: newField
                        width: Math.max(140, Math.min(240, root.width - 260))
                        placeholder: "Nome do novo perfil"
                        invalid: root.nameBad
                        Component.onCompleted: input.maximumLength = 32
                        onAccepted: text => {
                            if (root.naming === "new" && newField.input.activeFocus)
                                root.finishNaming(text)
                        }
                    }
                    Button {
                        text: "Salvar"
                        primary: true
                        onClicked: root.finishNaming(newField.input.text)
                    }
                    Button {
                        text: "Cancelar"
                        flat: true
                        onClicked: root.cancelNaming()
                    }
                }
            }
            Connections {
                target: newField.input
                function onTextChanged() {
                    root.nameBad = false
                }
                // Esc (the field's own) or a click elsewhere: nothing saved
                function onActiveFocusChanged() {
                    if (!newField.input.activeFocus && root.naming === "new")
                        root.cancelNaming()
                }
            }
        }

        Flow {
            id: grid
            width: parent.width
            spacing: 12
            Repeater {
                model: root.profiles
                Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool renaming: root.naming === "rename" && root.renamingId === modelData.id
                    width: root.cellWidth
                    height: card.implicitHeight
                    z: handle.dragging ? 3 : root.menuId === modelData.id ? 2 : 0
                    ProfileCard {
                        id: card
                        width: parent.width
                        colors: ProfileStore.colorsOf(cell.modelData)
                        name: cell.renaming ? "" : cell.modelData.nome
                        picture: ProfileStore.pictureUrl(cell.modelData)
                        marks: true
                        active: cell.modelData.id === ProfileStore.active
                        dirty: active && ProfileStore.dirty
                        chosen: active
                        focusRing: active && root.activeFocus
                        opacity: handle.dragging ? 0.85 : 1
                    }
                    MouseArea {
                        id: handle
                        // (the Padrão stays first: only the owner's move)
                        readonly property bool dragging: drag.active
                        property bool moved: false
                        width: card.width
                        height: Math.round(card.width * 4 / 3)
                        cursorShape: Qt.PointingHandCursor
                        drag.target: cell.modelData.builtin ? null : card
                        drag.threshold: 8
                        onPressed: moved = false
                        onPositionChanged: {
                            if (drag.active)
                                moved = true
                        }
                        onReleased: mouse => {
                            if (!moved)
                                return
                            const p = mapToItem(grid, mouse.x, mouse.y)
                            const col = Math.max(0, Math.min(root.columns - 1, Math.floor(p.x / (root.cellWidth + grid.spacing))))
                            const row = Math.max(0, Math.floor(p.y / (card.implicitHeight + grid.spacing)))
                            const place = Math.min(root.profiles.length - 1, Math.max(1, row * root.columns + col)) - 1
                            card.x = 0
                            card.y = 0
                            root.moveTo(cell.modelData.id, place)
                        }
                        onClicked: {
                            root.forceActiveFocus()
                            if (!moved)
                                root.apply(cell.modelData)
                        }
                    }
                    // "⋯": the card's menu (never the Padrão's)
                    Rectangle {
                        id: dots
                        visible: !cell.modelData.builtin && !handle.dragging
                        // (inside the card's frame, never on it)
                        x: card.width - width - card.inset
                        y: card.inset
                        width: 26; height: 22; radius: 6
                        color: Theme.alpha(Theme.bgHard, root.menuId === cell.modelData.id ? 0.95 : 0.75)
                        opacity: root.canAct ? 1 : 0.5
                        Text {
                            anchors.centerIn: parent
                            text: "⋯"
                            color: Theme.text
                            font.family: Theme.fontPanels
                            font.pointSize: Theme.fontSize
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.menuId === cell.modelData.id ? root.closeMenu() : root.openMenu(cell.modelData.id, dots)
                        }
                    }
                    // The name, as a field while it is renamed
                    Field {
                        id: renameField
                        visible: cell.renaming
                        x: 0
                        y: Math.round(card.width * 4 / 3) + 2
                        width: card.width
                        height: 24
                        value: root.renameText
                        invalid: root.nameBad
                        Component.onCompleted: input.maximumLength = 32
                        onVisibleChanged: {
                            if (visible) {
                                input.text = root.renameText
                                input.forceActiveFocus()
                                input.selectAll()
                            }
                        }
                        onAccepted: text => {
                            if (cell.renaming && input.activeFocus)
                                root.finishNaming(text)
                        }
                        // Esc (the field's own) or a click elsewhere: the
                        // name stays as it was
                        Connections {
                            target: renameField.input
                            function onTextChanged() {
                                root.nameBad = false
                            }
                            function onActiveFocusChanged() {
                                if (!target.activeFocus && cell.renaming)
                                    root.cancelNaming()
                            }
                        }
                    }
                }
            }
            // The last card: "Novo perfil"
            Rectangle {
                id: newCard
                width: root.cellWidth
                height: Math.round(width * 4 / 3)
                radius: Theme.radius
                color: newMouse.containsMouse && root.canAct && !root.full ? Theme.alpha(Theme.fg, 0.05) : Theme.clear
                opacity: root.canAct && !root.full ? 1 : 0.5
                Behavior on color {
                    ColorAnimation { duration: Theme.dur(Theme.animFast) }
                }
                // a dashed border, rounded
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: 2
                        strokeColor: Theme.alpha(Theme.fg, 0.3)
                        fillColor: Theme.clear
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [3, 3]
                        PathRectangle {
                            x: 1; y: 1
                            width: newCard.width - 2
                            height: newCard.height - 2
                            radius: Theme.radius
                        }
                    }
                }
                Column {
                    visible: root.naming !== "plus"
                    anchors.centerIn: parent
                    width: parent.width - 16
                    spacing: 4
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "󰐕"
                        color: Theme.text
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize + 6
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: root.full ? `No máximo ${Profile.MAX} perfis` : "Novo perfil"
                        textFormat: Text.PlainText
                        color: Theme.text
                        font.family: Theme.fontPanels
                        font.pointSize: Theme.fontSize - 1
                    }
                    Text {
                        visible: !root.full
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "a partir do que está agora"
                        textFormat: Text.PlainText
                        color: Theme.fg4
                        font.family: Theme.fontPanels
                        font.pointSize: Theme.fontSize - 2
                    }
                }
                MouseArea {
                    id: newMouse
                    anchors.fill: parent
                    visible: root.naming !== "plus"
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startNew("plus")
                }
                // The new profile's name, inside the card
                Column {
                    visible: root.naming === "plus"
                    anchors.centerIn: parent
                    width: parent.width - 16
                    spacing: 8
                    Field {
                        id: plusField
                        width: parent.width
                        placeholder: "Nome do novo perfil"
                        invalid: root.nameBad
                        Component.onCompleted: input.maximumLength = 32
                        onAccepted: text => {
                            if (root.naming === "plus" && plusField.input.activeFocus)
                                root.finishNaming(text)
                        }
                        Connections {
                            target: plusField.input
                            function onTextChanged() {
                                root.nameBad = false
                            }
                            function onActiveFocusChanged() {
                                if (!plusField.input.activeFocus && root.naming === "plus")
                                    root.cancelNaming()
                            }
                        }
                    }
                    Row {
                        id: plusButtons
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6
                        Button {
                            text: "Salvar"
                            primary: true
                            onClicked: root.finishNaming(plusField.input.text)
                        }
                        Button {
                            text: "Cancelar"
                            flat: true
                            onClicked: root.cancelNaming()
                        }
                    }
                }
            }
        }

        // Import from the export folder
        Button {
            text: root.importOpen ? "Fechar a importação" : `Importar de ${ProfileStore.exportsShown || "Documentos/Perfis"}`
            flat: true
            enabled: !root.locked
            onClicked: root.toggleImports()
        }
        Column {
            visible: root.importOpen
            width: parent.width
            spacing: 6
            Text {
                visible: ProfileStore.importsTotal > ProfileStore.imports.length
                width: parent.width
                wrapMode: Text.WordWrap
                text: `Mostrando ${ProfileStore.imports.length} de ${ProfileStore.importsTotal}.`
                textFormat: Text.PlainText
                color: Theme.fg4
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize - 2
            }
            Text {
                visible: ProfileStore.importsRead && ProfileStore.imports.length === 0
                width: parent.width
                wrapMode: Text.WordWrap
                text: `Nenhum perfil exportado em ${ProfileStore.exportsShown}.`
                textFormat: Text.PlainText
                color: Theme.fg4
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize - 1
            }
            Repeater {
                model: root.importOpen ? ProfileStore.imports : []
                Rectangle {
                    required property var modelData
                    width: parent.width
                    height: 40
                    radius: Theme.radius
                    color: Theme.bg1
                    Column {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - importButton.width - 36
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: parent.parent.modelData.nome + (parent.parent.modelData.theme !== "" ? ` · ${parent.parent.modelData.theme}` : "")
                            textFormat: Text.PlainText
                            color: Theme.text
                            font.family: Theme.fontPanels
                            font.pointSize: Theme.fontSize - 1
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: `pasta ${parent.parent.modelData.folder}`
                            textFormat: Text.PlainText
                            color: Theme.fg4
                            font.family: Theme.fontPanels
                            font.pointSize: Theme.fontSize - 2
                        }
                    }
                    Button {
                        id: importButton
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Importar"
                        outline: true
                        enabled: root.canAct && !root.full
                        opacity: enabled ? 1 : 0.5
                        onClicked: root.importFolder(parent.modelData.folder)
                    }
                }
            }
        }

        // Reading or writing; what did not work
        Text {
            visible: text !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            text: ProfileStore.reading ? "Lendo os perfis…" : ProfileStore.busy ? "Gravando…" : ""
            textFormat: Text.PlainText
            color: Theme.fg4
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 2
        }
        Text {
            visible: root.naming !== "" && root.nameBad
            width: parent.width
            wrapMode: Text.WordWrap
            text: "De 1 a 32 caracteres: letras, números, espaços e . _ -, com ao menos uma letra ou número, sem espaço nas pontas e sem “..”."
            textFormat: Text.PlainText
            color: Theme.yellow
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 2
        }
        Text {
            visible: root.notice !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.notice
            textFormat: Text.PlainText
            color: Theme.yellow
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 2
        }
    }

    // ── The open menu: over everything, closed by a click outside ──
    MouseArea {
        anchors.fill: parent
        visible: root.menuId !== ""
        z: 9
        onClicked: root.closeMenu()
    }
    Rectangle {
        id: menu
        visible: root.menuId !== ""
        z: 10
        x: Math.max(0, Math.min(root.width - width, root.menuX - width))
        y: root.menuY + 4
        width: 190
        height: menuColumn.implicitHeight + 8
        radius: Theme.radius
        color: Theme.bg1
        border.width: 1
        border.color: Theme.alpha(Theme.fg, 0.12)
        Column {
            id: menuColumn
            x: 4
            y: 4
            width: parent.width - 8
            Repeater {
                model: [{ id: "rename", label: "Renomear" }, { id: "duplicate", label: "Duplicar" },
                        { id: "export", label: "Exportar" }, { id: "exportbare", label: "Exportar sem a imagem" },
                        { id: "line" }, { id: "remove", label: "Apagar…" }]
                Item {
                    id: menuItem
                    required property var modelData
                    width: menuColumn.width
                    height: modelData.id === "line" ? 9 : 28
                    visible: modelData.id !== "duplicate" || !root.full
                    Rectangle {
                        visible: menuItem.modelData.id === "line"
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 1
                        color: Theme.alpha(Theme.fg, 0.12)
                    }
                    Rectangle {
                        visible: menuItem.modelData.id !== "line"
                        opacity: root.canAct ? 1 : 0.5
                        anchors.fill: parent
                        radius: Theme.radius - 2
                        color: itemMouse.containsMouse ? Theme.bg2 : (menuItem.modelData.id === "remove" && root.armed ? Theme.danger : Theme.clear)
                        Text {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: menuItem.modelData.id === "remove" && root.armed ? "Confirmar?" : (menuItem.modelData.label || "")
                            textFormat: Text.PlainText
                            color: menuItem.modelData.id === "remove" ? Theme.red : Theme.text
                            font.family: Theme.fontPanels
                            font.pointSize: Theme.fontSize - 1
                        }
                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.canAct
                            onClicked: root.menuAction(menuItem.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
