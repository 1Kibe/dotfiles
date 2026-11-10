import QtQuick
import qs.theme

// The cascade of one item (a sidebar row, a card): it comes in from the
// left (Theme.cascadeShift → 0) while it fades in, with the expressive curve
// and a slight overshoot; it leaves fading out. Reduce motion keeps only the
// fades; speed 0 shows and hides at once. The item gives its Translate.
Item {
    id: root

    required property Item target
    required property Translate translate

    // Never drawn, and skipped by the layouts it sits in
    visible: false
    width: 0
    height: 0

    function shown() {
        inAnim.stop()
        outAnim.stop()
        target.opacity = 1
        translate.x = 0
    }
    function hidden() {
        inAnim.stop()
        outAnim.stop()
        target.opacity = 0
        translate.x = Theme.reduceMotion ? 0 : -Theme.cascadeShift
    }
    function playIn(delay) {
        outAnim.stop()
        hidden()
        inPause.duration = Theme.dur(delay)
        inAnim.restart()
    }
    function playOut(delay) {
        inAnim.stop()
        outPause.duration = Theme.dur(delay)
        outAnim.restart()
    }

    SequentialAnimation {
        id: inAnim
        PauseAnimation { id: inPause }
        ParallelAnimation {
            NumberAnimation {
                target: root.target
                property: "opacity"
                to: 1
                duration: Theme.dur(Theme.cascadeItem)
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root.translate
                property: "x"
                to: 0
                duration: Theme.dur(Theme.cascadeItem)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveExpressive
            }
        }
    }
    SequentialAnimation {
        id: outAnim
        PauseAnimation { id: outPause }
        NumberAnimation {
            target: root.target
            property: "opacity"
            to: 0
            duration: Theme.dur(Theme.cascadeOutItem)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveAccel
        }
    }
}
