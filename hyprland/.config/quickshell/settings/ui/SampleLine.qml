import QtQuick
import qs.theme

// A line of text of the theme editor's preview: plain text, cut with "…",
// in the panels' font (its color comes from the theme being made)
Text {
    textFormat: Text.PlainText
    elide: Text.ElideRight
    font.family: Theme.fontPanels
    font.pointSize: Theme.fontSize - 1
}
