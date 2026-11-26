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
                    readonly property int d: index - CarouselState.index
                    readonly property int ad: Math.abs(d)
                    width: fan.width
                    height: card.implicitHeight
                    z: 100 - ad
                    visible: ad <= 3
                    x: d === 0 ? 0 : Math.sign(d) * (fan.width * 0.42 + (ad - 1) * fan.width * 0.3)
                    scale: Math.pow(0.82, ad)
                    opacity: ad === 0 ? 1 : ad === 3 ? 0 : 1 - ad * 0.2
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
                    }
                    MouseArea {
                        width: card.width
                        height: Math.round(card.width * 4 / 3)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: slot.d === 0 ? CarouselState.applyPicked() : CarouselState.pick(slot.index)
                    }
                }
            }
        }

        // ── The grid (more than six) ──
        Grid {
            id: gridView
            visible: view.grid
            anchors.centerIn: parent
            readonly property real cell: Theme.profileCardWidth * 0.6
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
                        onClicked: parent.picked ? CarouselState.applyPicked() : CarouselState.pick(parent.index)
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
