.pragma library

// Values from Hyprland that go back into a dispatcher (Lua run by
// Hyprland): checked here, one place for every caller. Plain JS: read by
// the shell and by the tests.

// A window's address, as Hyprland's "address:" selector takes it: "0x" and
// hex digits (Quickshell can give it without the prefix). Anything else:
// "" (the caller does nothing)
function windowAddress(address) {
    if (typeof address !== "string")
        return ""
    const lower = address.trim().toLowerCase()
    const hex = lower.startsWith("0x") ? lower : `0x${lower}`
    return /^0x[0-9a-f]{1,16}$/.test(hex) ? hex : ""
}
