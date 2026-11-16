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
// Mount points of the system: a disk with a partition on one of these is
// never listed
var SYSTEM_MOUNTS = ["/", "/boot", "/boot/efi", "/efi", "/home", "[SWAP]"]

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

// `lpstat -v` → [{ name, scheme, medium }]: the configured queues. A line
// that does not fit, a name that does not pass or a repeated one is left out
function parsePrintersV(out) {
    const res = []
    const seen = {}
    for (const line of lines(out)) {
        const m = /^device for ([^:\s]+): ([A-Za-z][A-Za-z0-9+.-]{0,31}):(\S*)$/.exec(line)
        if (!m || !printerName(m[1]) || seen[m[1]])
            continue
        seen[m[1]] = true
        const scheme = m[2].toLowerCase()
        res.push({ name: m[1], scheme: scheme, medium: medium(scheme) })
        if (res.length >= MAX_PRINTERS)
            break
    }
    return res
}

// `lpstat -p -- <name>` → "idle", "printing", "stopped" or "unknown". Only
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
    const seen = {}
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
// ("" when it does not pass); the header and anything else are left out
function parseTitles(out) {
    const res = {}
    for (const line of lines(out)) {
        const m = /^(\S+)\s+(\S+)\s+([0-9]{1,10})\s+(.+?)\s+([0-9]+) bytes$/.exec(line)
        if (m)
            res[m[3]] = text(m[4])
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

// lsblk's JSON → [{ dev, parent, label, size, fstype, mounted, mountpoint,
// avail, auto }]: only partitions (or whole disks without a table) of a disk
// on USB or a card reader, removable or plugged in while running, with a
// filesystem the page mounts, and never a disk with a partition of the
// system. mountpoint: "" unless mounted where the page may open it
function parseLsblk(out, user) {
    if (typeof out !== "string" || out.length > MAX_JSON)
        return []
    let data = null
    try {
        data = JSON.parse(out)
    } catch (e) {
        return []
    }
    const disks = own(data, "blockdevices") && Array.isArray(data.blockdevices) ? data.blockdevices : []
    const res = []
    for (const disk of disks) {
        if (!disk || typeof disk !== "object" || disk.type !== "disk")
            continue
        if (!["usb", "mmc"].includes(disk.tran) || !(flag(disk.rm) || flag(disk.hotplug)))
            continue
        const kids = Array.isArray(disk.children) ? disk.children.filter(c => c && typeof c === "object") : []
        const all = [disk].concat(kids)
        if (all.some(d => mountsOf(d).some(p => SYSTEM_MOUNTS.includes(p))))
            continue
        const parts = kids.length > 0 ? kids.filter(c => c.type === "part") : [disk]
        for (const p of parts) {
            const dev = `/dev/${p.name}`
            const fstype = typeof p.fstype === "string" ? p.fstype.toLowerCase() : ""
            if (typeof p.name !== "string" || !BLOCK_DEV.test(dev))
                continue
            if (!AUTO_FS.includes(fstype) && !MANUAL_FS.includes(fstype))
                continue
            const mounts = mountsOf(p)
            const open = mounts.find(m => validMountpoint(m, user)) || ""
            res.push({
                dev: dev,
                parent: `/dev/${disk.name}`,
                label: text(p.label),
                size: bytes(p.size),
                fstype: fstype,
                mounted: mounts.length > 0,
                mountpoint: open,
                avail: mounts.length > 0 ? bytes(p.fsavail) : null,
                auto: AUTO_FS.includes(fstype)
            })
            if (res.length >= MAX_DRIVES)
                return res
        }
    }
    return res
}

// ── USB (sysfs) ──

// One line per device of /sys/bus/usb/devices (the state reads only these
// files, never serial): "deviceClass<TAB>interface classes, comma
// separated<TAB>manufacturer<TAB>product" → { devices: [{ name, hid,
// storage, alsoKeyboard }], hubs } (hubs and host controllers counted on
// one line; at most 64 devices)
function usbList(out) {
    const devices = []
    let hubs = 0
    for (const line of lines(out)) {
        const f = line.split("\t")
        if (f.length !== 4)
            continue
        const cls = f[0].trim().toLowerCase()
        const ifaces = f[1].split(",").map(s => s.trim().toLowerCase()).filter(s => /^[0-9a-f]{2}$/.test(s))
        if (!/^[0-9a-f]{2}$/.test(cls))
            continue
        if (cls === "09" || ifaces.includes("09")) {
            hubs++
            continue
        }
        const name = text(f[3]) || text(f[2]) || "Dispositivo USB"
        const hid = cls === "03" || ifaces.includes("03")
        const storage = cls === "08" || ifaces.includes("08")
        if (devices.length < MAX_USB)
            devices.push({ name: name, hid: hid, storage: storage, alsoKeyboard: hid && storage })
    }
    return { devices: devices, hubs: hubs }
}
