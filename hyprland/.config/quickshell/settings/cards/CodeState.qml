import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.state
import "../ui"
import "../codecards.js" as Cards
import "../gitwrite.js" as GitWrite

// Configurações → Contas de código → Estado: per folder, whether it is there
// and whether git's files hold what the page says (read again after each
// change), and Conferir: which e-mail git would really use there, compared
// with the profile's inside the script (settings/codecards.js
// CHECK_SCRIPT) and shown only as ok / diferente. No e-mail, path or
// account goes to the log. Hidden with no folder.
ColumnLayout {
    id: root

    readonly property bool locked: CodeAccounts.locked
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string profilesText: SettingsStore.get("codeProfiles") || "[]"
    readonly property string foldersText: SettingsStore.get("codeFolders") || "[]"
    readonly property var profiles: Cards.list(profilesText)
    readonly property var folders: Cards.list(foldersText)
    readonly property bool empty: folders.length === 0

    property var info: ({ files: {}, dirs: [], idFile: false })
    // The state's reading ended (with no answer for a folder: it failed)
    property bool infoDone: false
    // Bumped at every change: a reading of the state started before it
    // brings back nothing (the next one comes)
    property int turn: 0
    property int stateTurn: 0
    property var checked: ({})
    property string stateInput: ""
    property string checkInput: ""
    // The lists a Conferir ran for: its answer counts only if they are the
    // same when it ends
    property string checkFor: ""

    spacing: 0

    // SettingsApply writes the files a moment after a change
    onProfilesTextChanged: changed()
    onFoldersTextChanged: changed()
    // What was read or checked belongs to the lists of before: gone at
    // once ("Lendo…"), and a Conferir still running is not shown
    function changed() {
        checked = ({})
        info = ({ files: {}, dirs: [], idFile: false })
        infoDone = false
        turn++
        later.restart()
    }
    Timer {
        id: later
        interval: 1500
        onTriggered: root.readState()
    }
    Component.onCompleted: readState()

    function readState() {
        if (stateJob.running) {
            later.restart()
            return
        }
        try {
            stateInput = Cards.stateInput(GitWrite.input(profiles, folders, home), folders)
        } catch (e) {
            stateInput = Cards.stateInput("", folders)
        }
        stateTurn = turn
        stateJob.stdinEnabled = true
        stateJob.running = true
    }
    Process {
        id: stateJob
        command: ["timeout", "-k", "2", "10", "bash", "-c", Cards.STATE_SCRIPT, "bash", SettingsApply.gitDir]
        stdout: StdioCollector {
            id: stateOut
        }
        stderr: StdioCollector {}
        onRunningChanged: {
            if (running) {
                write(root.stateInput)
                stdinEnabled = false
            }
        }
        onExited: {
            root.stateInput = ""
            if (root.stateTurn !== root.turn)
                return
            root.info = Cards.parseState(stateOut.text)
            root.infoDone = true
        }
    }

    function check() {
        if (checkJob.running || locked)
            return
        checked = ({})
        checkInput = Cards.checkInput(folders, profiles)
        checkFor = checkInput
        checkJob.stdinEnabled = true
        checkJob.running = true
    }
    Process {
        id: checkJob
        command: ["timeout", "-k", "2", "30", "bash", "-c", Cards.CHECK_SCRIPT, "bash", Quickshell.shellPath(".")]
        stdout: StdioCollector {
            id: checkOut
        }
        stderr: StdioCollector {}
        onRunningChanged: {
            if (running) {
                write(root.checkInput)
                stdinEnabled = false
            }
        }
        onExited: {
            root.checkInput = ""
            const same = root.checkFor === Cards.checkInput(root.folders, root.profiles)
            root.checkFor = ""
            if (same)
                root.checked = Cards.parseCheck(checkOut.text)
        }
    }

    Repeater {
        model: root.folders
        OptionRow {
            id: line
            required property var modelData
            required property int index
            readonly property string word: root.checked[index] !== undefined ? Cards.checkWord(root.checked[index]) : ""
            divider: index > 0
            label: modelData.path
            desc: Cards.folderState(modelData, index, root.info, root.profiles, root.infoDone)
            Text {
                visible: text !== ""
                text: checkJob.running ? "conferindo…" : line.word
                textFormat: Text.PlainText
                color: root.checked[line.index] === "ok" ? Theme.green
                     : root.checked[line.index] === "diferente" ? Theme.yellow : Theme.fg4
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize - 1
            }
        }
    }

    OptionRow {
        divider: true
        label: "Conferir"
        desc: "Pergunta ao git qual e-mail ele usaria em cada pasta. Sem repositório na pasta, cria um temporário e apaga em seguida"
        Button {
            text: checkJob.running ? "Conferindo…" : "Conferir"
            enabled: !root.locked && !checkJob.running
            opacity: enabled ? 1 : 0.5
            onClicked: root.check()
        }
    }

    Text {
        visible: root.info.idFile
        Layout.fillWidth: true
        Layout.margins: 8
        text: "A ~/.ssh/config tem IdentityFile: se a chave do perfil for recusada, o ssh tenta também essa."
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.yellow
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }
}
