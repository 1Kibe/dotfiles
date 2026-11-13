import QtQuick
import qs.state

// While an arrangement is being tried (state/MonitorsApply): the strip
// (KeepStrip) asking to keep the screens, with the seconds left.
KeepStrip {
    shown: MonitorsApply.pending
    question: `Manter estas telas? Volta em ${MonitorsApply.left} s`
    namespace: "quickshell-monitor-keep"
    onKeep: MonitorsApply.keep()
    onBack: MonitorsApply.revert()
}
