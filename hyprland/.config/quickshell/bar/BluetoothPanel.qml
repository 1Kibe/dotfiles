import QtQuick
import QtQuick.Layouts
import qs.control

// Bluetooth panel of the bar: the same list as the control center's
// Bluetooth section (control/BluetoothList), hanging from the Bluetooth
// button.
AttachedPanel {
    id: root

    panelWidth: 320

    BluetoothList {
        active: root.open
    }
}
