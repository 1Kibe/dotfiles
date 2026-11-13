import QtQuick
import qs.state

// While a keyboard layout is being tried (state/KeyboardLayout): the strip
// (KeepStrip) asking to keep it, with the seconds left. Manter works with the
// mouse alone, for a layout that types the wrong keys.
KeepStrip {
    shown: KeyboardLayout.pending
    question: `Manter este teclado? Volta em ${KeyboardLayout.left} s`
    namespace: "quickshell-keyboard-keep"
    onKeep: KeyboardLayout.keep()
    onBack: KeyboardLayout.revert()
}
