import QtQuick
import Quickshell

// The login screen: Quickshell inside cage, run by greetd as the "greeter"
// user (system/greetd/config.toml). install.sh copies this folder to
// /etc/greetd/quickshell together with the session's theme and the parts of
// the lock screen it shares (clock, user picture, password field, status).
ShellRoot {
    Greeter {}
}
