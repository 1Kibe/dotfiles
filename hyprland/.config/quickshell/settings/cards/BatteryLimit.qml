import QtQuick
import qs.state
import "../ui"

// Configurações → Energia → Bateria: the battery charge limit (Lenovo
// IdeaPad and Yoga, state/EnergyApply). The switch shows what the kernel
// says; a change goes as a boolean and waits for the kernel's answer (the
// switch rests until then). Without the kernel's file (a VM, another
// machine) there is nothing to show: `empty` hides the group.
OptionRow {
    id: root

    readonly property bool empty: !EnergyApply.conservationAvailable

    label: "Limite de carga"
    desc: "Para de carregar em cerca de 60%: a bateria dura mais quando fica sempre na tomada"

    Toggle {
        checked: EnergyApply.conservation
        enabled: !EnergyApply.conservationBusy
        opacity: enabled ? 1 : 0.5
        onToggled: v => EnergyApply.setConservation(v)
    }
}
