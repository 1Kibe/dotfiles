import QtQuick
import QtQuick.Layouts
import qs.control

// Volume panel of the bar: the same mixer as the control center's mixer
// section (control/AudioMixer), with the output's own level on top,
// hanging from the volume button.
AttachedPanel {
    id: root

    panelWidth: 340

    AudioMixer {
        active: root.open
        outputLevel: true
    }
}
