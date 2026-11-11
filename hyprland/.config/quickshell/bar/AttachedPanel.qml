import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.state

// Base of the panels that hang from the bar: drawn inside the bar's own
// window (the frame, Bar.qml), right under the bar, by AttachedShape, with
// concave corners where its sides meet the bar. One surface for bar and
// panel, so they blur as one shape.
//
// Under `button`, right-aligned to it (alignLeft: left edges lined up;
// centered: under its middle). side "right" continues the bar's right end
// instead (the power menu), and the bar squares that corner while the panel
// shows; a panel whose concave corner would pass one of the bar's ends snaps
// to that end the same way.
//
// Opening unrolls the body from the bar while the concave corners grow
// (AttachedShape.progress) and the content slides down with it; closing
// rolls it back up, and only then the panel hides. Every opening starts
// rolled up; a click in the middle of an animation goes on from where it is.
// Esc and a click outside (the frame's focus grab) close it the same way.
//
// edgeSide "left"/"right": the body goes to that screen edge, past the
// bar's side gap, and opens on the edge timeline (bar/EdgeTimeline): the
// bar first stretches that end to the screen's edge and squares that
// corner, then the body unrolls; closing, the other way round. No panel
// uses it yet (the settings, on the left, are their own piece).
Item {
    id: root

    required property Item button
    required property bool open        // from ShellState
    property int panelWidth: Theme.panelWidth
    property bool centered: false      // under the middle of the button
    property bool alignLeft: false     // left edges lined up (buttons on the left of the bar)
    property string side: "center"     // "right": continues the bar's right end
    property string edgeSide: ""       // "left"/"right": to the screen's edge (see above)
    // One piece with the button (the music panel and the center island): the
    // shape also takes the button's box, from the screen's top edge down, and
    // the body is never narrower than the button plus its inner corners
    property bool joinButton: false
    // Hangs over Print's capture (CapturePanel): the frame stays in the
    // Overlay layer until it has rolled back
    property bool overCapture: false
    default property alias content: body.data
    // Over the content, not clipped by the body (the music panel's cover and
    // equalizer flying in from the island), in this item's coordinates
    property alias overlay: overlayItem.data
    // The shape's fill; with a cover (fillCover, an image URL), the cover
    // blurred like the center island's fills the shape, with fillShade over it
    property color fillColor: Theme.barFill
    property string fillCover: ""
    property color fillShade: Theme.clear

    // The bar's edge and the body's left edge, in this item's coordinates
    readonly property real junctionY: shape.junctionY
    readonly property real bodyLeft: shape.bodyX
    // Its outline (SVG path), at (x, y) in the frame: Print's overlay keeps
    // its veil out of it (bar/CapturePanel)
    readonly property alias outline: shape.outline

    // Where an item of the content sits once the panel is open, in this
    // item's coordinates: a fixed spot, not the content sliding in
    function openPos(item) {
        const p = item.mapToItem(slide, 0, 0)
        return Qt.point(shape.bodyX + p.x, shape.junctionY + p.y)
    }

    // The frame this panel hangs from (the button's window): drawn in its
    // panel layer, above the bar
    readonly property var frame: button ? button.QsWindow.window : null
    parent: frame ? frame.panelLayer : null

    // 0 = rolled up, 1 = open; drives the shape, the content and the mask.
    // On the edge timeline, its panel part
    property real progress: 0
    Binding on progress {
        when: root.edgeSide !== ""
        value: edgeTimeline.panelStep
    }
    // What the frame reads to stretch the bar's end (Bar.qml)
    readonly property real edgeStep: edgeSide !== "" ? edgeTimeline.barStep : 0
    // Set by place(): whether the body continues one of the bar's ends
    property bool atLeftEnd: false
    property bool atRightEnd: false
    // The monitor it was opened on, for the bar's square corner
    property string shownOn: ""

    // The room it needs under the bar (the frame grows to it) and the
    // clickable pieces: the visible body and the two concave corners
    readonly property real roomHeight: shape.implicitHeight - shape.junctionY
    readonly property Region maskRegion: Region {
        item: bodyArea
        Region { item: leftCorner }
        Region { item: rightCorner }
    }

    visible: false
    width: shape.implicitWidth
    height: shape.implicitHeight

    // The body's width: never narrower than the button it joins plus room
    // for the inner corners on both sides
    readonly property real bodyWidth: joinButton && button
                                      ? Math.max(panelWidth, button.width + 2 * shape.fullReach)
                                      : panelWidth

    // Full height of the body: the content plus its 6 px margin above and
    // below. Animated, so a panel whose content grows (a list loading)
    // resizes smoothly.
    property real bodyHeight: body.implicitHeight + 12
    Behavior on bodyHeight {
        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
    }

    // Body position on the bar, in the frame's coordinates: under the bar,
    // one corner's room left of the body
    function place() {
        if (!frame || !button)
            return
        const bar = frame.barArea
        const p = button.mapToItem(bar, 0, 0)
        const barWidth = bar.width
        const panelWidth = bodyWidth
        let left = centered ? p.x + button.width / 2 - panelWidth / 2
                 : alignLeft ? p.x
                 : p.x + button.width - panelWidth
        let atRight = side === "right"
        let atLeft = false
        if (edgeSide === "right") {
            // To the screen's edge: past the bar's side gap
            left = barWidth - panelWidth + bar.x
            atRight = true
        } else if (edgeSide === "left") {
            left = -bar.x
            atLeft = true
        } else {
            // A concave corner must never hang past the bar's end
            if (atRight || left + panelWidth > barWidth - shape.fullReach) {
                left = barWidth - panelWidth
                atRight = true
            }
            if (left < shape.fullReach) {
                left = 0
                atLeft = true
            }
        }
        atLeftEnd = atLeft
        atRightEnd = atRight
        x = Math.round(bar.x + left) - shape.bodyX
        // Joined to the button: from the screen's top, the button's box over
        // the body
        y = joinButton ? bar.y : bar.y + bar.height
        if (joinButton)
            shape.islandX = bar.x + p.x - x
    }

    // A body that changes width while it shows (the capture pill gains
    // buttons in Vídeo) is placed again
    onBodyWidthChanged: {
        if (visible)
            place()
    }

    // The bar squares its end while a panel continues it
    function square() {
        shownOn = ShellState.openOn
        if (atRightEnd)
            ShellState.attachedRight = shownOn
        if (atLeftEnd)
            ShellState.attachedLeft = shownOn
    }
    function unsquare() {
        if (shownOn !== "" && ShellState.attachedRight === shownOn)
            ShellState.attachedRight = ""
        if (shownOn !== "" && ShellState.attachedLeft === shownOn)
            ShellState.attachedLeft = ""
        shownOn = ""
    }

    // Rolled up and hidden: the frame shrinks back and the bar's end rounds
    function hidden() {
        visible = false
        if (edgeSide === "")
            progress = 0
        unsquare()
        if (frame)
            frame.hidePanel(root)
    }

    // A button that moves or resizes (the island growing with the music, a
    // status item appearing) takes the panel with it
    Connections {
        target: root.button
        function onXChanged() { if (root.visible) root.place() }
        function onWidthChanged() { if (root.visible) root.place() }
    }
    Connections {
        target: root.button ? root.button.parent : null
        function onXChanged() { if (root.visible) root.place() }
        function onWidthChanged() { if (root.visible) root.place() }
    }
    // The bar's area the button sits in (a centered row moves when an item
    // in it grows, as the clock does into the music island)
    Connections {
        target: root.button && root.button.parent ? root.button.parent.parent : null
        function onXChanged() { if (root.visible) root.place() }
    }

    onOpenChanged: {
        if (open) {
            leave.stop()
            // Reopening in the middle of a close goes on from where it is;
            // a hidden panel starts rolled up
            if (!visible) {
                if (edgeSide === "")
                    progress = 0
                else
                    edgeTimeline.reset()
            }
            place()
            square()
            frame.showPanel(root)
            visible = true
            if (edgeSide === "")
                enter.restart()
            else
                edgeTimeline.open()
            // Focus on the body so Esc reaches its key handler
            body.forceActiveFocus()
        } else {
            enter.stop()
            if (visible) {
                if (edgeSide === "")
                    leave.restart()
                else
                    edgeTimeline.close()
            }
        }
    }

    NumberAnimation {
        id: enter
        target: root
        property: "progress"
        to: 1
        duration: Theme.dur(Theme.motionPanelOpen)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curveDecel
    }

    // Shorter than the entry: closing should feel quicker. The panel hides
    // only after the body is rolled up.
    SequentialAnimation {
        id: leave
        NumberAnimation {
            target: root
            property: "progress"
            to: 0
            duration: Theme.dur(Theme.motionPanelClose)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveAccel
        }
        ScriptAction { script: root.hidden() }
    }

    EdgeTimeline {
        id: edgeTimeline
        onClosed: root.hidden()
    }

    // Drawn in the frame's shape layer (under the bar's items), at this
    // panel's place: the fill
    AttachedShape {
        id: shape
        parent: root.frame ? root.frame.shapeLayer : root
        x: root.x
        y: root.y
        width: implicitWidth
        height: implicitHeight
        visible: root.visible
        flareLeft: !root.atLeftEnd
        flareRight: !root.atRightEnd
        bodyWidth: root.bodyWidth
        bodyHeight: root.bodyHeight
        progress: root.progress
        islandWidth: root.joinButton && root.button ? root.button.width : 0
        islandHeight: root.joinButton && root.frame ? root.frame.barArea.height : 0
        islandRadius: Theme.barRadius
        fill: root.fillColor
    }

    // With a cover (the music panel): the cover, blurred and shaded like the
    // center island's (CoverBackdrop), cut by the same outline. The cut is a
    // mask: a white copy of the outline drawn only into a texture
    // (hideSource), never on the screen. The blur stays cached in
    // CoverBackdrop; only the cut follows the animation.
    Item {
        parent: root.frame ? root.frame.shapeLayer : root
        // Over the plain shape: both go to the shape layer, in no set order
        z: 1
        x: root.x
        y: root.y
        width: shape.width
        height: shape.height
        visible: root.visible && root.fillCover !== ""

        Shape {
            id: coverMask
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "white"
                strokeWidth: -1
                PathSvg { path: shape.outline }
            }
        }
        ShaderEffectSource {
            id: coverMaskTexture
            anchors.fill: parent
            sourceItem: coverMask
            hideSource: true
            visible: false
        }
        CoverBackdrop {
            anchors.fill: parent
            source: root.fillCover
            shown: true
            color: Theme.clear
            bottomLeftRadius: 0
            bottomRightRadius: 0
            shade: root.fillShade
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: coverMaskTexture
                // Inside where the mask is over half covered, with a soft edge
                // from the outline's own antialiasing
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }
    }

    // Mask pieces (see maskRegion): the visible body and the two corners
    Item {
        id: bodyArea
        x: shape.bodyX
        y: shape.junctionY
        width: root.bodyWidth
        height: shape.visibleHeight
    }
    Item {
        id: leftCorner
        x: shape.bodyX - width
        y: shape.junctionY
        width: shape.flareLeft ? shape.flareReach : 0
        height: width
    }
    Item {
        id: rightCorner
        x: shape.bodyX + root.bodyWidth
        y: shape.junctionY
        width: shape.flareRight ? shape.flareReach : 0
        height: width
    }

    // The visible part of the body: the content slides down inside it as the
    // body unrolls. Its round corners take the continuous corner's whole
    // reach, so the clip always stays inside the shape's corners.
    ClippingRectangle {
        x: shape.bodyX
        y: shape.junctionY
        width: root.bodyWidth
        height: shape.visibleHeight
        color: Theme.clear
        bottomLeftRadius: shape.bottomReach
        bottomRightRadius: shape.bottomReach

        Item {
            id: slide
            width: parent.width
            height: root.bodyHeight
            y: shape.visibleHeight - root.bodyHeight
            // Drawn once into a texture while it moves, so its children are
            // not repainted on every frame of the animation
            layer.enabled: enter.running || leave.running || edgeTimeline.running

            // Children of the panel land here (the `content` alias); its
            // implicit height sizes the body
            ColumnLayout {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                spacing: 2
                focus: true
                Keys.onEscapePressed: ShellState.close()
            }
        }
    }

    Item {
        id: overlayItem
        anchors.fill: parent
    }
}
