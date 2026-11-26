import QtQuick
import qs.theme
import qs.state
import "../ui"
import "../profile.js" as Profile

// Configurações → Perfis: one poster per profile (the Padrão first, then the
// owner's in their order) and, last, "Salvar como perfil". A click applies
// the profile; the pencil on an own one picks it for the actions without
// applying it. The actions act on the one picked (the active one until
// another is picked): Salvar no perfil (today's values into it), Renomear,
// Duplicar, Apagar (two clicks), and Voltar ao padrão. A name is asked in a
// field of its own and checked before anything is written. Dragging an own
// card onto another's place reorders them (Ctrl+arrows with the keyboard);
// the arrows apply the neighbor. While the folders are read or written the
// buttons wait, with a word saying so; what did not work stays written
// below until the next action. Nothing is written with the screen locked.
Item {
    id: root

    activeFocusOnTab: true

    readonly property var profiles: ProfileStore.profiles
    readonly property bool locked: LockState.locked || LockState.wanted
    readonly property bool canAct: !locked && !ProfileStore.busy && ProfileStore.ready
    // The one the actions act on ("" = the Padrão)
    property string pickedId: ProfileStore.active
    readonly property var picked: ProfileStore.get(pickedId) ?? ProfileStore.padrao
    readonly property bool pickedOwn: picked !== null && !picked.builtin
    readonly property bool full: Object.keys(ProfileStore.found).length >= Profile.MAX
    // "" | "save" | "rename": the field asking for a name
    property string naming: ""
    // The profile being renamed (the one picked when the field opened)
    property string namingId: ""
    property bool nameBad: false
    property string notice: ""
    property bool armed: false
    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = false
    }
    Connections {
        target: ProfileStore
        function onFailed(message) {
            root.notice = message
            Qt.callLater(root.settlePick)
        }
        function onDone(what, id) {
            if (what === "create" || what === "duplicate")
                root.pickedId = id
            else if (what === "remove" && root.pickedId === id)
                root.pickedId = ProfileStore.active
        }
    }
    // A picked one gone (removed by another way): back to the active one
    Connections {
        target: ProfileStore
        function onFoundChanged() {
            if (ProfileStore.get(root.pickedId) === null)
                root.pickedId = ProfileStore.active
        }
    }
    // Another one picked: Apagar disarms and the rename field closes (they
    // were for the one before)
    onPickedIdChanged: {
        armed = false
        disarm.stop()
        if (naming === "rename")
            naming = ""
    }
    readonly property string busyText: "Espere: os perfis ainda estão sendo lidos ou gravados."
    // A profile clicked whose change has not happened yet; once every change
    // ends (or one fails), the pick follows what is really active
    property string applying: ""
    function settlePick() {
        if (applying === "" || SwapState.busy)
            return
        applying = ""
        pickedId = ProfileStore.active
    }
    Connections {
        target: SwapState
        function onEnded() {
            Qt.callLater(root.settlePick)
        }
    }

    // An action: never silent (busy, or the store refused without saying why)
    function act(fn) {
        notice = ""
        armed = false
        disarm.stop()
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
        if (locked || p === null)
            return
        if (ProfileStore.apply(p.id, { fromCursor: true })) {
            pickedId = p.id
            // (applied a moment later: if it never is, the pick goes back)
            if (ProfileStore.active !== p.id)
                applying = p.id
        } else if (notice === "")
            notice = "Não deu para aplicar o perfil: nada mudou."
    }
    function startNaming(kind) {
        if (!canAct || (kind === "save" && full) || (kind === "rename" && !pickedOwn))
            return
        naming = kind
        namingId = kind === "rename" ? pickedId : ""
        nameBad = false
        nameField.value = kind === "rename" ? picked.nome : ""
        nameField.input.text = nameField.value
        nameField.input.forceActiveFocus()
    }
    function finishNaming(text) {
        if (naming === "")
            return
        if (!Profile.checkName(text)) {
            nameBad = true
            return
        }
        const kind = naming, id = namingId
        nameBad = false
        if (act(() => kind === "save" ? ProfileStore.save(text) : ProfileStore.rename(id, text)))
            naming = ""
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
    // (nothing while a name is being typed)
    function arrow(dir, ctrl) {
        if (naming !== "")
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

    implicitHeight: column.implicitHeight
    Column {
        id: column
        width: parent.width
        spacing: 12

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
                    width: root.cellWidth
                    height: card.implicitHeight
                    z: handle.dragging ? 2 : 0
                    ProfileCard {
                        id: card
                        width: parent.width
                        colors: ProfileStore.colorsOf(cell.modelData)
                        name: cell.modelData.nome
                        picture: ProfileStore.pictureUrl(cell.modelData)
                        marks: true
                        active: cell.modelData.id === ProfileStore.active
                        dirty: active && ProfileStore.dirty
                        chosen: cell.modelData.id === root.pickedId
                        focusRing: active && root.activeFocus
                        opacity: handle.dragging ? 0.85 : 1
                    }
                    MouseArea {
                        id: handle
                        // (the Padrão stays first: only the owner's move)
                        readonly property bool dragging: drag.active
                        property bool moved: false
                        anchors.fill: card
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
                    // The pencil: picks an own one for the actions, without
                    // applying it
                    Rectangle {
                        visible: !cell.modelData.builtin && !handle.dragging
                        x: card.width - width - 6
                        y: 6
                        width: 24; height: 24; radius: 6
                        color: Theme.alpha(Theme.bgHard, 0.85)
                        Text {
                            anchors.centerIn: parent
                            text: "󰏫"
                            color: Theme.text
                            font.family: Theme.font
                            font.pointSize: Theme.fontSize - 1
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.notice = ""
                                root.armed = false
                                root.pickedId = cell.modelData.id
                            }
                        }
                    }
                }
            }
            // The last card: "Salvar como perfil"
            Rectangle {
                width: root.cellWidth
                height: Math.round(width * 4 / 3)
                radius: Theme.radius
                color: saveMouse.containsMouse && root.canAct && !root.full ? Theme.bg2 : Theme.bg1
                opacity: root.canAct && !root.full ? 1 : 0.5
                border.width: 1
                border.color: Theme.alpha(Theme.fg, 0.15)
                Behavior on color {
                    ColorAnimation { duration: Theme.dur(Theme.animFast) }
                }
                Column {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    spacing: 6
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
                        text: root.full ? `No máximo ${Profile.MAX} perfis` : "Salvar como perfil"
                        textFormat: Text.PlainText
                        color: Theme.fg4
                        font.family: Theme.fontPanels
                        font.pointSize: Theme.fontSize - 1
                    }
                }
                MouseArea {
                    id: saveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startNaming("save")
                }
            }
        }

        // The name being asked (a new profile, or the picked one renamed)
        Connections {
            target: nameField.input
            function onTextChanged() {
                root.nameBad = false
            }
        }
        Row {
            visible: root.naming !== ""
            spacing: 8
            Field {
                id: nameField
                width: Math.max(120, Math.min(260, root.width - 200))
                Component.onCompleted: input.maximumLength = 32
                placeholder: "Nome do perfil"
                invalid: root.nameBad
                onAccepted: text => {
                    if (root.naming !== "" && nameField.input.activeFocus)
                        root.finishNaming(text)
                }
            }
            Button {
                text: root.naming === "rename" ? "Renomear" : "Salvar"
                primary: true
                onClicked: root.finishNaming(nameField.input.text)
            }
            Button {
                text: "Cancelar"
                onClicked: {
                    root.naming = ""
                    root.nameBad = false
                }
            }
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

        // The picked one's actions
        Flow {
            width: parent.width
            spacing: 8
            visible: root.naming === ""
            enabled: root.canAct
            opacity: enabled ? 1 : 0.5
            Button {
                visible: root.pickedOwn && root.pickedId === ProfileStore.active
                text: "Salvar no perfil"
                primary: ProfileStore.dirty
                onClicked: root.act(() => ProfileStore.saveActive())
            }
            Button {
                visible: root.pickedOwn
                text: "Renomear"
                onClicked: root.startNaming("rename")
            }
            Button {
                visible: root.pickedOwn && !root.full
                text: "Duplicar"
                onClicked: root.act(() => ProfileStore.duplicate(root.pickedId))
            }
            // Two clicks: the first arms it for 3 s
            Button {
                visible: root.pickedOwn
                text: root.armed ? "Confirmar?" : "Apagar"
                danger: root.armed
                destructive: true
                onClicked: {
                    if (!root.armed) {
                        root.notice = ""
                        root.armed = true
                        disarm.restart()
                        return
                    }
                    const id = root.pickedId
                    root.act(() => ProfileStore.remove(id))
                }
            }
            Button {
                visible: ProfileStore.active !== "" || ProfileStore.dirty
                text: "Voltar ao padrão"
                onClicked: root.apply(ProfileStore.padrao)
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
}
