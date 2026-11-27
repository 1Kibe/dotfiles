import QtQuick
import qs.theme
import qs.state
import "../settings/ui"

// Super+T's cards (profiles/ProfileOverlay draws it on the monitor it
// opened on): the picked one in the middle, larger and lighter, its
// neighbors in a fan, smaller and darker, fading out at the ends; more than
// Theme.profileFanMax, a grid over the whole screen; under them the name and
// "perfil ativo · N / M". Arrows, the wheel, a click and 1 to 9 pick; Enter
// (or a click on the picked one) applies; Esc closes (state/CarouselState).
Item {
    id: view
    readonly property bool grid: CarouselState.count > Theme.profileFanMax
    // Shown (the overlay up): the fan opens out from the middle and closes
    // back into it; reduce motion: no slide (the overlay's fade only)
    property bool shown: true
    property real spread: shown ? 1 : 0.6
    Behavior on spread {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: Theme.dur(Theme.motionPanelOpen); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel }
    }
    readonly property alias keys: keyArea
    Item {
        id: keyArea
        anchors.fill: parent
        Keys.onPressed: event => {
            const k = event.key
            const cols = view.grid ? gridView.columns : 1
            if (k === Qt.Key_Escape)
                CarouselState.close()
            else if (k === Qt.Key_Return || k === Qt.Key_Enter)
                CarouselState.applyPicked()
            else if (k === Qt.Key_Left)
                CarouselState.step(-1)
            else if (k === Qt.Key_Right)
                CarouselState.step(1)
            else if (k === Qt.Key_Up && view.grid)
                CarouselState.step(-cols)
            else if (k === Qt.Key_Down && view.grid)
                CarouselState.step(cols)
            else if (k >= Qt.Key_1 && k <= Qt.Key_9)
                CarouselState.pick(k - Qt.Key_1)
            else
                return
            event.accepted = true
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => CarouselState.step(event.angleDelta.y > 0 || event.angleDelta.x > 0 ? -1 : 1)
        }

        // ── The fan (up to six) ──
        Item {
            id: fan
            visible: !view.grid
            anchors.centerIn: parent
            width: Theme.profileCardWidth
            height: Math.round(Theme.profileCardWidth * 4 / 3)
            Repeater {
                model: view.grid ? [] : ProfileStore.profiles
                Item {
                    id: slot
                    required property var modelData
                    required property int index
                    // (round: the first one's left neighbor is the last)
                    readonly property int d: {
                        const n = CarouselState.count, raw = index - CarouselState.index
                        if (n < 3)
                            return raw
                        const m = ((raw % n) + n) % n
                        return m > n / 2 ? m - n : m
                    }
                    readonly property int ad: Math.abs(d)
                    width: fan.width
                    height: card.implicitHeight
                    z: 100 - ad
                    // (the ones past the fan's ends: neither seen nor clicked)
                    visible: ad <= 2
                    x: (d === 0 ? 0 : Math.sign(d) * (fan.width * 0.42 + (ad - 1) * fan.width * 0.3)) * view.spread
                    scale: Math.pow(0.82, ad)
                    opacity: ad === 0 ? 1 : 1 - ad * 0.2
                    Behavior on opacity {
                        enabled: !Theme.reduceMotion
                        NumberAnimation { duration: Theme.dur(Theme.animNormal) }
                    }
                    Behavior on x {
                        enabled: !Theme.reduceMotion
                        NumberAnimation { duration: Theme.dur(Theme.animNormal); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveStandard }
                    }
                    Behavior on scale {
                        enabled: !Theme.reduceMotion
                        NumberAnimation { duration: Theme.dur(Theme.animNormal); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveStandard }
                    }
                    ProfileCard {
                        id: card
                        width: parent.width
                        colors: ProfileStore.colorsOf(slot.modelData)
                        name: ""
                        picture: ProfileStore.pictureUrl(slot.modelData)
                    }
                    // The neighbors darker
                    Rectangle {
                        width: card.width
                        height: Math.round(card.width * 4 / 3)
                        radius: Theme.radius
                        color: Theme.bgDeep
                        opacity: Math.min(0.7, slot.ad * 0.3)
                        Behavior on opacity {
                            enabled: !Theme.reduceMotion
                            NumberAnimation { duration: Theme.dur(Theme.animNormal) }
                        }
                    }
                    MouseArea {
                        width: card.width
                        height: Math.round(card.width * 4 / 3)
                        cursorShape: Qt.PointingHandCursor
                        // (a click: the circle starts from the cursor)
                        onClicked: slot.d === 0 ? CarouselState.applyPicked({ fromCursor: true }) : CarouselState.pick(slot.index)
                    }
                }
            }
        }

        // ── The grid (more than six) ──
        Grid {
            id: gridView
            visible: view.grid
            anchors.centerIn: parent
            // The cell fits the screen's height too (24 on a small screen):
            // the columns by the width, then the rows by the height left
            // above the name
            readonly property real room: view.height - 160
            readonly property real base: Theme.profileCardWidth * 0.6
            readonly property int cols0: Math.max(1, Math.floor((view.width - 2 * Theme.gap * 4) / (base + spacing)))
            readonly property int rows0: Math.max(1, Math.ceil(CarouselState.count / cols0))
            readonly property real cell: Math.max(60, Math.min(base, (room - (rows0 - 1) * spacing) / rows0 * 3 / 4))
            columns: Math.max(1, Math.floor((view.width - 2 * Theme.gap * 4) / (cell + spacing)))
            spacing: Theme.gap * 2
            Repeater {
                model: view.grid ? ProfileStore.profiles : []
                Item {
                    required property var modelData
                    required property int index
                    readonly property bool picked: index === CarouselState.index
                    width: gridView.cell
                    height: Math.round(gridView.cell * 4 / 3)
                    scale: picked ? 1.06 : 1
                    z: picked ? 1 : 0
                    Behavior on scale {
                        enabled: !Theme.reduceMotion
                        NumberAnimation { duration: Theme.dur(Theme.animFast) }
                    }
                    ProfileCard {
                        width: parent.width
                        colors: ProfileStore.colorsOf(parent.modelData)
                        name: ""
                        picture: ProfileStore.pictureUrl(parent.modelData)
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius
                        color: Theme.bgDeep
                        opacity: parent.picked ? 0 : 0.45
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.picked ? CarouselState.applyPicked({ fromCursor: true }) : CarouselState.pick(parent.index)
                    }
                }
            }
        }

        // The name and the count, under the cards
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: view.grid ? gridView.y + gridView.height + Theme.gap * 3
                        : fan.y + Math.round(fan.width * 4 / 3) + Theme.gap * 3
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: CarouselState.picked ? CarouselState.picked.nome : ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                width: Math.min(implicitWidth, view.width - 64)
                color: Theme.text
                font.family: Theme.fontPanels
                font.weight: Font.Light
                font.pointSize: Theme.fontSize + 8
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (CarouselState.picked && CarouselState.picked.id === ProfileStore.active ? "perfil ativo · " : "")
                      + `${CarouselState.index + 1} / ${CarouselState.count}`
                textFormat: Text.PlainText
                color: Theme.gray
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize - 1
            }
        }
    }
}
