import QtQuick
import Quickshell
import qs.bar

// The shell: one bar per monitor. Later modules (launcher, notifications...)
// get their own folder and a line here.
ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Bar {}
        }
    }
}
