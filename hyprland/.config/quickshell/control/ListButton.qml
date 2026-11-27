import QtQuick
import QtQuick.Layouts
import qs.theme

// A button of the sections' lists, the same in all of them: the main one
// (primary: the light fill, dark text, as "Atualizar tudo no terminal")
// and the others (the dark fill, as "Verificar agora"); compact for the
// small ones inside a row ("Esquecer", "Desconectar"). `danger` is an
// armed action waiting for its second click. fadeText: a new text fades in
// ("Copiar" → "Copiado").
Rectangle {
    id: root

    property string icon
    property string text
    property bool primary: false
    property bool compact: false
    property bool danger: false
    property bool fadeText: false
    // The keyboard is on it (a ring of the Theme)
    property bool keyFocus: false
    signal clicked()
    onTextChanged: {
        if (fadeText)
            labelFade.restart()
    }
    NumberAnimation {
        id: labelFade
        target: row
        property: "opacity"
        from: 0
        to: 1
        duration: Theme.dur(Theme.animFast)
    }

    implicitWidth: row.implicitWidth + (compact ? 16 : 24)
    implicitHeight: compact ? Theme.itemHeight : 32
    radius: Theme.radius
    color: primary ? (mouse.pressed ? Theme.fg4 : Theme.accentLight)
         : danger ? Theme.danger
         : mouse.pressed || mouse.containsMouse ? Theme.bg2 : Theme.bg1
    Behavior on color {
        ColorAnimation { duration: Theme.dur(Theme.animFast) }
    }
    border.width: keyFocus ? Theme.focusWidth : 0
    border.color: primary ? Theme.fg : Theme.focusRing

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: root.icon !== ""
            text: root.icon
            textFormat: Text.PlainText
            color: label.color
            font.family: Theme.font
            font.pointSize: root.compact ? Theme.fontSizeSmall : Theme.fontSize
        }
        Text {
            id: label
            text: root.text
            textFormat: Text.PlainText
            color: root.primary ? Theme.onAccent : root.danger ? Theme.red : Theme.fg2
            Behavior on color {
                ColorAnimation { duration: Theme.dur(Theme.animFast) }
            }
            font.family: Theme.font
            font.pointSize: root.compact ? Theme.fontSizeSmall : Theme.fontSize - 1
            font.weight: Font.Medium
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
