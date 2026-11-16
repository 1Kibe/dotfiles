.pragma library
.import "apps.js" as Apps

// Configurações → Dispositivos, the parts with no state: what the page reads
// from lsblk, the CUPS commands and the USB folders of sysfs, checked before
// it is shown or passed to a command. Plain JS: read by state/DrivesState,
// state/PrintersState and the tests. Every text from outside (labels, job
// titles, USB names) goes through the same filter as settings/apps.js and is
// cut at 64 characters; it is only ever shown as plain text.

var MAX_JSON = 512 * 1024
var MAX_TEXT = 64 * 1024
var MAX_LINES = 1000
var MAX_PRINTERS = 64
var MAX_JOBS = 200
var MAX_DRIVES = 32
var MAX_USB = 64

// A printer name the page passes to lpstat, lpoptions, lp and cancel: only
// names from `lpstat -v`, this shape, and never one of a network service
// (DNS-SD) or a .local host
var PRINTER_NAME = /^[A-Za-z0-9][A-Za-z0-9._-]{0,126}$/
// A partition udisksctl may get (the lsblk list decides which of these)
var BLOCK_DEV = /^\/dev\/(sd[a-z]+[0-9]*|mmcblk[0-9]+p[0-9]+|nvme[0-9]+n[0-9]+p[0-9]+)$/
var USER_NAME = /^[a-z_][a-z0-9_-]{0,31}$/

// Mounted on their own (simple, common on pendrives and cards); the others
// only by the "Montar" button
var AUTO_FS = ["vfat", "exfat"]
var MANUAL_FS = ["ntfs", "ntfs3", "ext4", "btrfs"]

function own(o, k) {
    return o !== null && typeof o === "object" && Object.prototype.hasOwnProperty.call(o, k)
}

// A text from outside as shown: filtered (Apps.BAD_TEXT), trimmed, cut at 64
// characters by code point (never in the middle of a pair); "" when it does
// not pass
function text(v) {
    if (typeof v !== "string" || v.length > 4096)
        return ""
    const t = v.trim()
    if (t === "" || Apps.BAD_TEXT.test(t))
        return ""
    const chars = []
    for (let i = 0; i < t.length;) {
        const c = t.codePointAt(i)
        chars.push(String.fromCodePoint(c))
        i += c > 0xffff ? 2 : 1
    }
    return chars.length > 64 ? chars.slice(0, 63).join("") + "…" : t
}

function lines(out) {
    if (typeof out !== "string" || out.length > MAX_TEXT)
        return []
    return out.split("\n").slice(0, MAX_LINES)
}

// ── Printers (CUPS, with LC_ALL=C) ──

function printerName(name) {
    if (typeof name !== "string" || !PRINTER_NAME.test(name))
        return false
    const low = name.toLowerCase()
    return low.indexOf("._tcp") < 0 && low.indexOf("._udp") < 0 && low.indexOf("._ipp") < 0
           && low.indexOf(".local") < 0
}

// How a printer is reached, from its URI's scheme only (never the host)
function medium(scheme) {
    if (scheme === "usb")
        return "usb"
    if (["ipp", "ipps", "http", "https", "socket", "lpd", "dnssd", "smb"].includes(scheme))
        return "rede"
    return "outro"
}

// A queue of a printer announced on the network (DNS-SD, a ".local" host):
// a dialog of an app may have made it from the discovery; it is shown as
// "da rede" and not used as the default nor for a test page. Only true or
// false comes out (the host is never kept)
function announced(scheme, rest) {
    if (scheme === "dnssd")
        return true
    const host = (/^\/\/([^/:?#]*)/.exec(rest || "") || [])[1] || ""
    const low = host.toLowerCase()
    return low.endsWith(".local") || low.endsWith(".local.") || low.indexOf("._ipp") >= 0 || low.indexOf("._tcp") >= 0
}

// `lpstat -v` → [{ name, scheme, medium, announced }]: the configured queues. A line
// that does not fit, a name that does not pass or a repeated one is left out
function parsePrintersV(out) {
    const res = []
    const seen = Object.create(null)
    for (const line of lines(out)) {
        const m = /^device for ([^:\s]+): ([A-Za-z][A-Za-z0-9+.-]{0,31}):(\S*)$/.exec(line)
        if (!m || !printerName(m[1]) || seen[m[1]])
            continue
        seen[m[1]] = true
        const scheme = m[2].toLowerCase()
        res.push({ name: m[1], scheme: scheme, medium: medium(scheme), announced: announced(scheme, m[3]) })
        if (res.length >= MAX_PRINTERS)
            break
    }
    return res
}

// `lpstat -p <name>` → "idle", "printing", "stopped" or "unknown" (no "--":
// lpstat would then ignore the name and list every printer). Only
// the first line counts: the lines after it are the printer's own message
// (which a printer may set, with line breaks, to look like another line)
function parsePrinterState(out, name) {
    const first = lines(out)[0] || ""
    const prefix = `printer ${name} `
    if (!printerName(name) || !first.startsWith(prefix))
        return "unknown"
    const rest = first.slice(prefix.length)
    if (rest.startsWith("is idle."))
        return "idle"
    if (rest.startsWith("now printing "))
        return "printing"
    if (rest.startsWith("disabled since "))
        return "stopped"
    return "unknown"
}

// `lpstat -d` → the default printer if it is one of `names`, else ""
function parseDefault(out, names) {
    const m = /^system default destination: (\S+)$/.exec(lines(out)[0] || "")
    return m && printerName(m[1]) && names.includes(m[1]) ? m[1] : ""
}

// A job id of one of `names`: "<name>-<number>" (the longest name that fits,
// as names may end in "-<digits>"); null when none
function jobOf(id, names) {
    if (typeof id !== "string" || id.length > 140)
        return null
    let best = null
    for (const n of names) {
        if (id.startsWith(n + "-") && /^[0-9]{1,10}$/.test(id.slice(n.length + 1)) && (!best || n.length > best.length))
            best = n
    }
    return best === null ? null : { id: id, printer: best, number: Number(id.slice(best.length + 1)) }
}

// `lpstat -o` → [{ id, printer, number, mine }]: jobs of known printers only;
// `user` is the session's (mine: the page may cancel it)
function parseJobs(out, names, user) {
    const res = []
    const seen = Object.create(null)
    for (const line of lines(out)) {
        const m = /^(\S+)\s+(\S+)\s+[0-9]+\s/.exec(line)
        if (!m)
            continue
        const job = jobOf(m[1], names)
        if (!job || seen[job.id])
            continue
        seen[job.id] = true
        job.mine = typeof user === "string" && user !== "" && m[2] === user
        res.push(job)
        if (res.length >= MAX_JOBS)
            break
    }
    return res
}

// `lpq -P <name>` → { number: title }: the file name of each job, filtered
// ("" when it does not pass); the header and anything else are left out.
// Split by fields, never by a pattern that backtracks (a long line of
// spaces would freeze the shell): lines over 512 characters are left out,
// the size is the last field before " bytes", the first three fields are
// rank, owner and job, the rest in between is the title
var MAX_LPQ_LINE = 512
function parseTitles(out) {
    const res = Object.create(null)
    for (const line of lines(out)) {
        if (line.length > MAX_LPQ_LINE || !line.endsWith(" bytes"))
            continue
        // No trimEnd in the QML engine: the trailing spaces by hand
        let end = line.length - " bytes".length
        while (end > 0 && line[end - 1] === " ")
            end--
        const body = line.slice(0, end)
        const sizeAt = body.lastIndexOf(" ")
        if (sizeAt < 0 || !/^[0-9]{1,20}$/.test(body.slice(sizeAt + 1)))
            continue
        const fields = body.slice(0, sizeAt).trim().split(/ +/)
        if (fields.length < 4 || !/^[0-9]{1,10}$/.test(fields[2]))
            continue
        res[fields[2]] = text(fields.slice(3).join(" "))
    }
    return res
}

// ── Removable drives (lsblk -J -b -o NAME,PKNAME,LABEL,SIZE,FSTYPE,FSAVAIL,
// MOUNTPOINTS,RM,HOTPLUG,TRAN,TYPE) ──

function flag(v) {
    return v === true || v === 1 || v === "1"
}
function bytes(v) {
    const n = typeof v === "string" && /^[0-9]{1,20}$/.test(v) ? Number(v) : v
    return typeof n === "number" && isFinite(n) && n >= 0 ? n : null
}
function mountsOf(dev) {
    const m = own(dev, "mountpoints") ? dev.mountpoints : []
    return Array.isArray(m) ? m.filter(p => typeof p === "string" && p !== "") : []
}
// A device and everything under it (partitions, and what lives on them:
// LUKS, LVM): at most 64 devices and 8 levels; past that, null (the checks
// that use it then take the unsafe answer: excluded, not unmounted)
function descendants(dev) {
    const out = []
    let over = false
    const walk = (d, depth) => {
        if (!d || typeof d !== "object")
            return
        if (out.length >= 64 || depth > 8) {
            over = true
            return
        }
        out.push(d)
        if (Array.isArray(d.children))
            d.children.forEach(c => walk(c, depth + 1))
    }
    walk(dev, 0)
    return over ? null : out
}
// A filesystem's UUID as lsblk gives it (part of a drive's token)
function uuidOf(d) {
    return typeof d.uuid === "string" && /^[A-Za-z0-9-]{1,64}$/.test(d.uuid) ? d.uuid : ""
}
// The disk of an eligible partition: the only kind powered off
var DISK_DEV = /^\/dev\/(sd[a-z]+|mmcblk[0-9]+)$/

// A mount point the page may open: right under /run/media/<user>/ (one
// folder), no "..", no control character
function validMountpoint(path, user) {
    if (typeof path !== "string" || typeof user !== "string" || !USER_NAME.test(user) || path.length > 4096)
        return false
    const base = `/run/media/${user}/`
    if (!path.startsWith(base))
        return false
    const rest = path.slice(base.length)
    return rest !== "" && rest !== "." && rest !== ".." && rest.indexOf("/") < 0 && !/[\u0000-\u001f\u007f]/.test(rest)
}

// lsblk's JSON (with UUID) → { ok, truncated, drives, present }.
// ok: the JSON was read as lsblk's (a failed read never empties anything);
// truncated: a limit was hit (more drives than 32, a disk too deep), so a
// missing drive may still be there; present: the token of every partition
// lsblk lists, eligible or not (a drive left out of `drives`, e.g. while a
// partition of its disk is mounted elsewhere, keeps its marks).
// drives: [{ dev, parent, label, size, fstype, uuid, mounted, mountpoint,
// avail, auto }]: only partitions (or whole disks without a table) of a
// disk on USB or a card reader, removable or plugged in while running, with
// a filesystem the page mounts. A disk with anything under it (at any
// depth: a partition, LUKS, LVM) mounted outside /run/media/<user>/ is left
// out whole: it may hold the system. mountpoint: the place to open, ""
// when not mounted
function readLsblk(out, user) {
    const none = { ok: false, truncated: false, drives: [], present: [] }
    if (typeof out !== "string" || out.length > MAX_JSON)
        return none
    let data = null
    try {
        data = JSON.parse(out)
    } catch (e) {
        return none
    }
    if (!own(data, "blockdevices") || !Array.isArray(data.blockdevices))
        return none
    const res = { ok: true, truncated: false, drives: [], present: [] }
    for (const disk of data.blockdevices) {
        if (!disk || typeof disk !== "object")
            continue
        const all = descendants(disk)
        if (all === null) {
            res.truncated = true
            continue
        }
        const kids = Array.isArray(disk.children) ? disk.children.filter(c => c && typeof c === "object") : []
        const parts = kids.length > 0 ? kids.filter(c => c.type === "part") : [disk]
        for (const p of parts)
            if (typeof p.name === "string")
                res.present.push(driveToken(entry(p, disk)))
        if (disk.type !== "disk" || !["usb", "mmc"].includes(disk.tran) || !(flag(disk.rm) || flag(disk.hotplug)))
            continue
        const parent = `/dev/${disk.name}`
        if (typeof disk.name !== "string" || !DISK_DEV.test(parent))
            continue
        if (all.some(d => mountsOf(d).some(m => !validMountpoint(m, user))))
            continue
        for (const p of parts) {
            const d = entry(p, disk)
            if (typeof p.name !== "string" || !BLOCK_DEV.test(d.dev))
                continue
            if (!AUTO_FS.includes(d.fstype) && !MANUAL_FS.includes(d.fstype))
                continue
            if (res.drives.length >= MAX_DRIVES) {
                res.truncated = true
                break
            }
            res.drives.push(d)
        }
    }
    return res
}
function entry(p, disk) {
    const fstype = typeof p.fstype === "string" ? p.fstype.toLowerCase() : ""
    const mounts = mountsOf(p)
    return {
        dev: `/dev/${p.name}`,
        parent: `/dev/${disk.name}`,
        label: text(p.label),
        size: bytes(p.size),
        fstype: fstype,
        uuid: uuidOf(p),
        mounted: mounts.length > 0,
        mountpoint: mounts.length > 0 ? mounts[0] : "",
        avail: mounts.length > 0 ? bytes(p.fsavail) : null,
        auto: AUTO_FS.includes(fstype)
    }
}
function parseLsblk(out, user) {
    return readLsblk(out, user).drives
}

// ── USB (sysfs) ──

// One line per device of /sys/bus/usb/devices (the state reads only these
// files, never serial, and removes every control character from the
// names, so a name can neither add a field nor a line): "deviceClass<TAB>
// interface classes, comma separated<TAB>manufacturer<TAB>product" →
// { devices: [{ name, hid, storage, alsoKeyboard }], hubs, unread,
// truncated }. A hub (device class 09 and every interface 09, or none) is
// counted on one line; a device that also has other interfaces is listed
// and marked. A line that cannot be read counts in `unread` (the page says
// so), never vanishes; past 64 devices, `truncated` says how many more
function usbList(out) {
    const devices = []
    let hubs = 0
    let unread = 0
    let truncated = 0
    for (const line of lines(out)) {
        if (line === "")
            continue
        const f = line.split("\t")
        const cls = f.length === 4 ? f[0].trim().toLowerCase() : ""
        if (f.length !== 4 || !/^[0-9a-f]{2}$/.test(cls)) {
            unread++
            continue
        }
        const ifaces = f[1].split(",").map(s => s.trim().toLowerCase()).filter(s => /^[0-9a-f]{2}$/.test(s))
        if (cls === "09" && ifaces.every(c => c === "09")) {
            hubs++
            continue
        }
        const name = text(f[3]) || text(f[2]) || "Dispositivo USB"
        const hid = cls === "03" || ifaces.includes("03")
        const storage = cls === "08" || ifaces.includes("08")
        if (devices.length < MAX_USB)
            devices.push({ name: name, hid: hid, storage: storage, alsoKeyboard: hid && storage })
        else
            truncated++
    }
    return { devices: devices, hubs: hubs, unread: unread, truncated: truncated }
}

// ── For state/DrivesState ──

// A drive's identity for the actions: the same name with another size,
// filesystem, UUID or label is another drive (a /dev name reused by a new
// one)
function driveToken(d) {
    return d ? `${d.dev}|${d.size}|${d.fstype}|${d.uuid || ""}|${d.label}` : ""
}

// lsblk's JSON → true when the disk `parent` and everything under it are
// unmounted (then it may be powered off); false on anything unexpected
function diskUnmounted(out, parent) {
    if (typeof out !== "string" || out.length > MAX_JSON || typeof parent !== "string" || !DISK_DEV.test(parent))
        return false
    let data = null
    try {
        data = JSON.parse(out)
    } catch (e) {
        return false
    }
    const disks = own(data, "blockdevices") && Array.isArray(data.blockdevices) ? data.blockdevices : []
    const disk = disks.find(d => d && typeof d === "object" && `/dev/${d.name}` === parent)
    if (!disk)
        return false
    const all = descendants(disk)
    return all !== null && all.every(d => mountsOf(d).length === 0)
}

// `hyprctl -j monitors` → true only when every screen is free of the session
// lock (no "LOCK" in solitaryBlockedBy, Hyprland's own word for it, the
// same read as hypr-travar's); anything else counts as locked
function screensUnlocked(out) {
    if (typeof out !== "string" || out.length > MAX_JSON)
        return false
    let data = null
    try {
        data = JSON.parse(out)
    } catch (e) {
        return false
    }
    if (!Array.isArray(data) || data.length === 0)
        return false
    return data.every(m => m && typeof m === "object" && Array.isArray(m.solitaryBlockedBy)
                           && !m.solitaryBlockedBy.includes("LOCK"))
}

// A label for the notification's body: filtered, cut at 64 and with the
// markup characters escaped (notification servers may read it as markup)
function notifyLabel(label) {
    return text(label).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

// udisksctl's error says the filesystem is in use
function busy(errText) {
    return typeof errText === "string" && /target is busy|device is busy|EBUSY/i.test(errText.slice(0, 4096))
}
