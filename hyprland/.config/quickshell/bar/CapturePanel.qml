import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import qs.capture

// Print's pill (T2b): the capture buttons hang from the bar's clock like
// the panels do, with the same concave corners and the same opening and
// closing. The capture itself (frozen screen, shade, selection) is a full
// screen layer above the bar; the frame goes up over it while the pill
// shows (Bar.qml, overCapture). Only on the focused monitor, and only once
// its frozen frame is taken: the bar is not part of the overlay, so a pill
// already open would end up in the picture.
AttachedPanel {
    id: root

    required property string monitorName

    overCapture: true
    centered: true
    panelWidth: buttons.implicitWidth + 12
    open: CaptureState.open && CaptureState.barReady && CaptureState.purpose !== "edit"
          && (CaptureState.phase === "select" || CaptureState.phase === "choose")
          && monitorName !== "" && CaptureState.focusName === monitorName

    // Its shape for the overlay below (CaptureOverlay): there the frozen
    // screen and its shade leave a hole, so the pill lies on the live screen
    // like the bar, with the same color and corners
    Binding {
        target: CaptureState
        property: "pill"
        when: root.monitorName !== "" && root.monitorName === CaptureState.focusName
        value: ({ x: root.x, y: root.y, path: root.visible ? root.outline : "" })
        restoreMode: Binding.RestoreNone
    }

    CaptureBar {
        id: buttons
        Layout.alignment: Qt.AlignHCenter
    }

    // What the hovered button does, or the next step: under the pill, fading
    // in and out with it
    overlay: Rectangle {
        x: root.bodyLeft + root.bodyWidth / 2 - width / 2
        // Past the pill: below it, or above it with the bar on the bottom edge
        y: root.mirrored ? root.junctionY - root.bodyHeight * root.progress - 6 - height
                         : root.junctionY + root.bodyHeight * root.progress + 6
        width: hintText.implicitWidth + 16
        height: hintText.implicitHeight + 8
        radius: height / 2
        color: Theme.stripFill
        visible: hintText.text !== ""
        opacity: root.progress

        Text {
            id: hintText
            anchors.centerIn: parent
            text: buttons.text
            color: Theme.fg4
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 2
        }
    }
}
