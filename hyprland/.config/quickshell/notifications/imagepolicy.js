.pragma library

// The picture of a notification (state/NotificationState, NotifImage): plain
// JS, read by the shell and by the tests. Only two things are ever shown:
// the image the protocol sent as data, which the Quickshell serves itself
// (DATA), and an icon of the theme by its plain name. Anything else (a
// file path, another image:// provider, a name with "/" or "..", any URL;
// image://icon/ only with a plain name after it)
// is none: the card shows no picture. Nothing here touches the disk.
//
// classify(value) → { kind: "none" | "data" | "icon", value }

// The address the Quickshell gives to an image sent as data
var DATA = /^image:\/\/qsimage\/[0-9]{1,12}(\/[0-9]{1,12})?$/
// A theme icon's name
var ICON = /^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$/
// Showing the protocol's image at all (off: initials and app icons only)
var IMAGES = true

var NONE = { kind: "none", value: "" }

function classify(value) {
    if (typeof value !== "string" || value === "" || value.length > 200)
        return NONE
    if (IMAGES && DATA.test(value))
        return { kind: "data", value: value }
    // A name the Quickshell wraps as image://icon/<name> (image-path):
    // the same name rule
    const name = value.startsWith("image://icon/") ? value.slice(13) : value
    if (ICON.test(name) && name.indexOf("..") < 0)
        return { kind: "icon", value: name }
    return NONE
}
