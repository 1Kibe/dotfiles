import QtQuick
import qs.theme

// A group's title in the theme editor's form
Text {
    topPadding: 10
    textFormat: Text.PlainText
    color: Theme.accentLight
    font.family: Theme.fontPanels
    font.pointSize: Theme.fontSize - 1
    font.bold: true
}
