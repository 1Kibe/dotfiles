import QtQuick
import QtQuick.Layouts
import qs.control

// Network panel of the bar: the same Wi-Fi list as the control center's
// Wi-Fi section (control/NetworkList), hanging from the network button.
AttachedPanel {
    id: root

    NetworkList {
        active: root.open
    }
}
