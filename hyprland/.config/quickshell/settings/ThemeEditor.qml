import QtQuick
import qs.theme
import qs.state
import "ui"
import "../theme/palettes.js" as Palettes
import "../theme/customtheme.js" as Custom

// Configurações › Temas › Novo tema personalizado: a theme of the owner's
// own, from a theme and flavor of the catalog or from scratch, every color
// editable (the backgrounds, the text tones with their contrast over the
// background, the seven named colors, the default accent, the terminal's
// eight, the type and delta's syntax theme), with a live preview. The shell
// only changes when it is saved; "Salvar e aplicar" also picks it. Saved
// out of the repo by ThemeCatalog.saveOwn. Narrow: one column, the preview
// on top.
Item {
    id: root

    signal closed()

    // "base" or "zero"
    property string mode: "base"
    property string baseTheme: ThemeCatalog.get(SettingsStore.values.theme ?? "") ? SettingsStore.values.theme : "gruvbox"
    property string baseFlavor: SettingsStore.values.flavor ?? "dark"
    property var model: Custom.fromBase(ThemeCatalog.get(baseTheme), baseFlavor)
    property string message: ""
    property string savingId: ""

    function reload() {
        const nome = model.nome
        const m = mode === "zero" ? Custom.fromScratch() : Custom.fromBase(ThemeCatalog.get(baseTheme), baseFlavor)
        m.nome = nome
        model = m
    }
    // A change of the model: a copy, so every binding follows
    function update(fn) {
        const m = JSON.parse(JSON.stringify(model))
        fn(m)
        model = m
    }
    function colorAt(path) {
        const [group, key] = path.split(".")
        return group === "ansi" ? model.ansi[Number(key)] : model[group][key]
    }
    function setColor(path, hex) {
        if (!Palettes.isHex(hex))
            return
        const [group, key] = path.split(".")
        update(m => {
            if (group === "ansi")
                m.ansi[Number(key)] = hex
            else
                m[group][key] = hex
        })
    }

    readonly property var contrasts: Custom.contrasts(model)
    function contrastOf(role) {
        const c = contrasts.find(x => x.role === role)
        return c ? { text: Custom.ratioText(c.ratio), ok: c.ok, least: c.least } : null
    }
    readonly property var low: contrasts.filter(c => !c.ok)
    readonly property var preview: ({
        roles: model.roles, named: model.named, ansi: model.ansi,
        accent: model.named[model.accent], accentLight: Custom.lightOf(model.named[model.accent])
    })

    readonly property var roleRows: [
        ["bgDeep", "Fundo mais escuro", "atrás de tudo"], ["bgHard", "Fundo forte", "barra e painéis"],
        ["bg", "Fundo", "janelas e cartões"], ["bg1", "Superfície", "blocos da Central"],
        ["bg2", "Superfície alta", "botões e bordas"]
    ]
    readonly property var textRows: [
        ["fg", "Texto", ""], ["fg2", "Texto secundário", ""], ["fg4", "Texto apagado", "horas, legendas"],
        ["text", "Texto da barra", ""], ["gray", "Cinza", "inativos"]
    ]
    readonly property var namedRows: [
        ["yellow", "Amarelo"], ["orange", "Laranja"], ["red", "Vermelho"], ["green", "Verde"], ["aqua", "Aqua"],
        ["blue", "Azul"], ["purple", "Roxo"]
    ]
    readonly property var ansiNames: ["Preto", "Vermelho", "Verde", "Amarelo", "Azul", "Magenta", "Ciano", "Branco"]
    readonly property var roleLabels: ({ fg: "Texto", fg2: "Texto secundário", fg4: "Texto apagado", text: "Texto da barra",
                                         gray: "Cinza" })

    // Saving: a new id, the model built and checked, then the catalog writes
    // it (never with the screen locked)
    function save(andApply) {
        message = ""
        if (LockState.locked || LockState.wanted)
            return
        const name = Custom.checkName(model.nome)
        if (!name.ok) {
            message = "Dê um nome ao tema (até 24 letras, números, espaço e . ' ( ) + -)."
            return
        }
        const id = Custom.newId(Math.random, ThemeCatalog.themes.map(t => t.id))
        const r = Custom.build(model, id)
        if (!r.ok) {
            message = "Alguma cor não é #rrggbb: confira os campos."
            return
        }
        savingId = id
        if (!ThemeCatalog.saveOwn(r.theme, andApply)) {
            savingId = ""
            message = "Não deu para salvar agora: tente de novo."
        }
    }
    Connections {
        target: ThemeCatalog
        function onSaveDone(ok, id) {
            if (root.savingId === "" || id !== root.savingId && ok)
                return
            const saved = root.savingId
            root.savingId = ""
            if (!ok) {
                root.message = "Não deu para gravar o tema: nada mudou."
                return
            }
            // (picked by the catalog once it reads it back, when asked)
            root.closed()
        }
    }

    readonly property bool narrow: width < 600
    readonly property real previewWidth: narrow ? width - 32 : Math.min(380, width * 0.45)

    // ── Top: title, the start (a theme or from scratch) and the name ──
    Column {
        id: top
        x: 16; y: 12
        width: parent.width - 32
        spacing: 10
        Text {
            text: "Novo tema personalizado"
            textFormat: Text.PlainText
            color: Theme.text
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize + 2
            font.bold: true
        }
        Flow {
            width: parent.width
            spacing: 10
            Segmented {
                options: [{ value: "base", label: "A partir de um tema" }, { value: "zero", label: "Do zero" }]
                value: root.mode
                onPicked: v => {
                    root.mode = v
                    root.reload()
                }
            }
            Dropdown {
                visible: root.mode === "base"
                options: ThemeCatalog.themes.map(t => ({ value: t.id, label: t.nome }))
                value: root.baseTheme
                onPicked: v => {
                    root.baseTheme = v
                    const t = ThemeCatalog.get(v)
                    if (t && !Object.prototype.hasOwnProperty.call(t.sabores, root.baseFlavor))
                        root.baseFlavor = Palettes.flavors(t)[0].id
                    root.reload()
                }
            }
            Dropdown {
                visible: root.mode === "base"
                options: ThemeCatalog.get(root.baseTheme) ? Palettes.flavors(ThemeCatalog.get(root.baseTheme)).map(f => ({ value: f.id, label: f.rotulo })) : []
                value: root.baseFlavor
                onPicked: v => {
                    root.baseFlavor = v
                    root.reload()
                }
            }
            Field {
                width: 200
                placeholder: "Nome"
                value: root.model.nome
                input.maximumLength: Custom.NAME_MAX
                onAccepted: t => root.update(m => { m.nome = t })
            }
        }
    }

    // ── The preview (fixed) ──
    Column {
        id: previewColumn
        x: root.narrow ? 16 : root.width - root.previewWidth - 16
        y: top.y + top.height + 12
        width: root.previewWidth
        spacing: 8
        ThemeSample {
            width: parent.width
            height: root.narrow ? Math.min(implicitHeight, 200) : implicitHeight
            colors: root.preview
        }
        Rectangle {
            visible: root.low.length > 0
            width: parent.width
            height: warn.implicitHeight + 16
            radius: Theme.radius
            color: Theme.alpha(Theme.yellow, 0.15)
            Text {
                id: warn
                x: 8; y: 8; width: parent.width - 16
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                color: Theme.yellow
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize - 2
                text: "Contraste abaixo do mínimo: "
                      + root.low.map(c => `${root.roleLabels[c.role]} ${Custom.ratioText(c.ratio)} (mínimo ${String(c.least).replace(".", ",")})`).join(", ")
                      + ". Dá para salvar assim mesmo."
            }
        }
    }

    // ── The form ──
    Flickable {
        id: form
        x: 16
        y: root.narrow ? previewColumn.y + previewColumn.height + 12 : previewColumn.y
        width: root.narrow ? root.width - 32 : root.width - root.previewWidth - 48
        height: footer.y - y - 12
        contentHeight: formColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: formColumn
            width: form.width
            spacing: 6

            FormTitle { text: "Tipo" }
            Segmented {
                options: [{ value: true, label: "Escuro" }, { value: false, label: "Claro" }]
                value: root.model.escuro
                onPicked: v => root.update(m => { m.escuro = v })
            }

            FormTitle { text: "Fundos" }
            Repeater {
                model: root.roleRows
                ColorRow {
                    required property var modelData
                    width: formColumn.width
                    label: modelData[1]; hint: modelData[2]
                    value: root.model.roles[modelData[0]]
                    onEdited: h => root.setColor("roles." + modelData[0], h)
                    onOpenPicker: sq => picker.openFor("roles." + modelData[0], sq)
                }
            }

            FormTitle { text: "Textos (contraste sobre o Fundo)" }
            Repeater {
                model: root.textRows
                ColorRow {
                    required property var modelData
                    width: formColumn.width
                    label: modelData[1]; hint: modelData[2]
                    value: root.model.roles[modelData[0]]
                    contrast: root.contrastOf(modelData[0])
                    onEdited: h => root.setColor("roles." + modelData[0], h)
                    onOpenPicker: sq => picker.openFor("roles." + modelData[0], sq)
                }
            }

            FormTitle { text: "As 7 cores" }
            Grid {
                columns: 2; columnSpacing: 12
                Repeater {
                    model: root.namedRows
                    ColorRow {
                        required property var modelData
                        width: (formColumn.width - 12) / 2
                        label: modelData[1]
                        value: root.model.named[modelData[0]]
                        onEdited: h => root.setColor("named." + modelData[0], h)
                        onOpenPicker: sq => picker.openFor("named." + modelData[0], sq)
                    }
                }
            }

            FormTitle { text: "Destaque padrão" }
            Row {
                spacing: 8
                Repeater {
                    model: root.namedRows
                    Rectangle {
                        required property var modelData
                        width: 26; height: 26; radius: 13
                        color: "transparent"
                        border.width: 2
                        border.color: root.model.accent === modelData[0] ? Theme.text : Theme.alpha(Theme.text, 0)
                        Rectangle { anchors.centerIn: parent; width: 18; height: 18; radius: 9; color: root.model.named[modelData[0]] }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.update(m => { m.accent = modelData[0] })
                        }
                    }
                }
            }

            FormTitle { text: "Terminal (as 8 cores escuras)" }
            Grid {
                columns: 2; columnSpacing: 12
                Repeater {
                    model: 8
                    ColorRow {
                        required property int index
                        width: (formColumn.width - 12) / 2
                        label: `${root.ansiNames[index]} (cor ${index})`
                        value: root.model.ansi[index]
                        onEdited: h => root.setColor("ansi." + index, h)
                        onOpenPicker: sq => picker.openFor("ansi." + index, sq)
                    }
                }
            }

            FormTitle { text: "Tema de sintaxe do delta" }
            Dropdown {
                options: Palettes.SYNTAX_THEMES.map(n => ({ value: n, label: n }))
                value: root.model.syntaxTheme
                onPicked: v => root.update(m => { m.syntaxTheme = v })
            }

            FormTitle { text: "Material"; opacity: 0.5 }
            Text {
                opacity: 0.5
                width: formColumn.width
                wrapMode: Text.WordWrap
                text: "Vidro (em breve): escolher o material junto com o tema"
                textFormat: Text.PlainText
                color: Theme.fg4
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize - 1
            }
            Item { width: 1; height: 8 }
        }
    }

    // ── Footer ──
    Row {
        id: footer
        anchors.right: parent.right
        anchors.rightMargin: 16
        y: parent.height - height - 12
        spacing: 8
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.message !== ""
            text: root.message
            textFormat: Text.PlainText
            color: Theme.yellow
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 2
        }
        Button { text: "Cancelar"; onClicked: root.closed() }
        Button { text: "Salvar"; onClicked: root.save(false) }
        Button { text: "Salvar e aplicar"; primary: true; onClicked: root.save(true) }
    }

    // ── The color picker, over everything; a click outside closes it ──
    MouseArea {
        anchors.fill: parent
        visible: picker.visible
        onClicked: picker.visible = false
    }
    ColorPicker {
        id: picker
        visible: false
        z: 2
        property string path: ""
        function openFor(p, square) {
            path = p
            value = root.colorAt(p)
            const at = square.mapToItem(root, 0, square.height + 4)
            x = Math.min(Math.max(8, at.x), root.width - width - 8)
            y = Math.min(at.y, root.height - height - 8)
            visible = true
        }
        onMoved: h => root.setColor(path, h)
        onDone: visible = false
    }
    Keys.onEscapePressed: event => {
        if (picker.visible) {
            picker.visible = false
            event.accepted = true
        }
    }
}
