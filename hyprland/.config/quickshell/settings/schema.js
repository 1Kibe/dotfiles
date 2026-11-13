.pragma library

// The settings of the shell: every key of the Configurações pages, its
// default (what the shell does today), its type and limits, whether it
// belongs to this machine only (machine: never exported to the repo), and
// where it shows (page and card), with the label, description and search
// synonyms in pt-BR. Plain JS: read by state/SettingsStore and by the tests.
//
// type: "bool" | "int" | "real" | "enum" | "string" | "color" | "path" | "list"
// - int / real: min, max, step
// - enum: options [{ value, label }]
// - string: pattern (a RegExp the whole text must match)
// - list: options [{ value, label }] (ids it may hold, each at most once)
// - path: absolute after "~" is expanded, no ".." part, no control character
// - source (string keys): the choices come from this machine
//   (state/SystemLists: "fonts", "monoFonts", "cursorThemes"); the page shows
//   only those, and SettingsApply uses a value only if it is one of them;
//   "monitors" (this machine's screens); emptyLabel: "" as a choice of its own
// - preview "fileName" (string keys): the description shows the name it
//   gives now, as an example
// - unit (int / real): written after the value ("8 px"; "s": a time, read in
//   s, min or h); format "percent": a 0-1 value read as a percent;
//   zeroLabel: what 0 reads as (settings/format.js)
// - pair: the key that shares this one's row on the page (the same option on
//   power and on battery); both keys name each other, same type and card
// - control "swatches" (enum keys of colors): dots in the color each option
//   gives, in place of the list
// - hidden: kept by the shell itself, never a row on the page nor a search
//   result
//
// A card: id, title; component (a special card, settings/cards/); strip (a
// preview at the top of the page, no title or block); columns (the titles
// of a paired row's two controls, [{ icon, label }]); flush (the component
// draws its own rows: no inner margin). A component may say `empty: true`
// (nothing to show here): its group hides

// ── Pages, in the order of the rail ──
var PAGES = [
    { id: "tema", group: "Aparência", icon: "󰏘", name: "Tema e cores", sub: "Destaque, transparência, cantos e cursor" },
    { id: "papel", group: "Aparência", icon: "󰸉", name: "Papel de parede", sub: "Imagem e preenchimento" },
    { id: "fontes", group: "Aparência", icon: "󰛖", name: "Fontes e animações", sub: "Fontes, tamanho do texto e velocidade" },
    { id: "barra", group: "Shell", icon: "󰕮", name: "Barra", sub: "Itens, posição e relógio" },
    { id: "bloqueio", group: "Shell", icon: "󰌾", name: "Bloqueio e login", sub: "Tela apagada e música" },
    { id: "captura", group: "Shell", icon: "󰄀", name: "Captura e clipboard", sub: "Pastas, OCR, gravação e histórico" },
    { id: "energia", group: "Sistema", icon: "󰂄", name: "Energia", sub: "Tempos, tampa e menu de energia" },
    { id: "monitores", group: "Sistema", icon: "󰍹", name: "Monitores", sub: "Arranjo, barra e luz noturna" },
    { id: "teclado", group: "Sistema", icon: "󰌌", name: "Teclado e mouse", sub: "Layout, repetição, mouse e touchpad" },
    { id: "atalhos", group: "Sistema", icon: "󰘳", name: "Atalhos", sub: "Lista dos atalhos" },
    { id: "apps", group: "Sistema", icon: "󰀻", name: "Apps padrão", sub: "Navegador, arquivos, terminal e outros" },
    { id: "sobre", group: "Sistema", icon: "󰋼", name: "Sobre", sub: "Versão, sistema e suas configurações" }
]

// ── Cards of each page; `component` names a special card (settings/cards/) ──
var CARDS = {
    tema: [{ id: "preview", title: "Tema atual", component: "ThemePreview", strip: true }, { id: "cores", title: "Cores" },
           { id: "superficies", title: "Superfícies" }, { id: "cursor", title: "Cursor" }],
    papel: [{ id: "imagem", title: "Imagem", component: "WallpaperGallery" }, { id: "ajuste", title: "Ajuste" }],
    fontes: [{ id: "previa", title: "Prévia da animação", component: "AnimationPreview", strip: true },
             { id: "fontes", title: "Fontes" }, { id: "animacoes", title: "Animações" }],
    barra: [{ id: "itens", title: "Itens", component: "BarItems" }, { id: "posicao", title: "Posição" },
            { id: "relogio", title: "Relógio" }],
    bloqueio: [{ id: "foto", title: "Foto", component: "UserPhoto" }, { id: "tela", title: "Tela" },
               { id: "seguranca", title: "Segurança", component: "LockSecurity" }],
    captura: [{ id: "capturas", title: "Capturas" }, { id: "gravacao", title: "Gravação" },
              { id: "clipboard", title: "Clipboard" }, { id: "limpar", title: "Histórico", component: "ClipboardClear" }],
    energia: [{ id: "avisos", title: "Avisos", component: "EnergyNotices", strip: true },
              { id: "tempos", title: "Inatividade",
                columns: [{ icon: "󰚥", label: "Na tomada" }, { icon: "󰁹", label: "Na bateria" }] },
              { id: "tampa", title: "Tampa" },
              { id: "bateria", title: "Bateria", component: "BatteryLimit", flush: true },
              { id: "menu", title: "Menu de energia" }],
    monitores: [{ id: "aviso", title: "Aviso", component: "MonitorNotice", strip: true },
                { id: "arranjo", title: "Arranjo", component: "MonitorLayout", flush: true },
                { id: "areas", title: "Áreas de trabalho" }, { id: "barra", title: "Barra" },
                { id: "luz", title: "Luz noturna" }],
    teclado: [{ id: "teclado", title: "Teclado" }, { id: "mouse", title: "Mouse" }, { id: "touchpad", title: "Touchpad" }],
    atalhos: [{ id: "lista", title: "Atalhos", component: "KeybindList" }],
    apps: [{ id: "apps", title: "Apps padrão" }],
    sobre: [{ id: "versao", title: "Versão", component: "AboutVersion" }, { id: "dados", title: "Suas configurações",
            component: "AboutData" }]
}

// ── Shared limits ──
// Names that go into generated files are checked against these first. They
// start with a letter or a digit, so none can pass for an option ("-x") or
// for "." / ".." (and later tasks still pass values after "--" or as
// absolute paths)
var FONT_NAME = /^[A-Za-z0-9][A-Za-z0-9 ._+-]{0,63}$/
var THEME_NAME = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/
// A screen's port name (eDP-1, HDMI-A-1, Virtual-1), the same shape as
// settings/monitors.js NAME: never a number or a word Hyprland reads as a
// selector (next, l, current)
var MONITOR_NAME = /^[A-Za-z]+(-[A-Za-z0-9]+)*-[0-9]{1,3}$/
var OPT_MONITOR = /^$|^[A-Za-z]+(-[A-Za-z0-9]+)*-[0-9]{1,3}$/
var DESKTOP_ID = /^[A-Za-z0-9][A-Za-z0-9._-]{0,95}\.desktop$/
var OPT_DESKTOP_ID = /^$|^[A-Za-z0-9][A-Za-z0-9._-]{0,95}\.desktop$/
var TIME_HM = /^([01][0-9]|2[0-3]):[0-5][0-9]$/
// Each screen's place in the areas (modules/areas.lua): "port:k" pairs, k
// from 1 to 9, at most 9 screens; state/AreasState checks them again (no
// repeated port or position)
var POSITIONS = /^$|^[A-Za-z]+(-[A-Za-z0-9]+)*-[0-9]{1,3}:[1-9](,[A-Za-z]+(-[A-Za-z0-9]+)*-[0-9]{1,3}:[1-9]){0,8}$/
// A capture's name: date fields that Qt writes as digits only (yy or yyyy,
// M, d, H, h, m, s up to two, z up to three; never MMM/ddd, which become
// words), each one whole (no letter right after the same letter), joined
// by "_", "." or "-"; 40 characters at most
var FILE_NAME_FORMAT = /^(?=.{1,40}$)(?:yyyy(?!y)|yy(?!y)|MM?(?!M)|dd?(?!d)|HH?(?!H)|hh?(?!h)|mm?(?!m)|ss?(?!s)|z{1,3}(?!z))(?:[_.-]|yyyy(?!y)|yy(?!y)|MM?(?!M)|dd?(?!d)|HH?(?!H)|hh?(?!h)|mm?(?!m)|ss?(?!s)|z{1,3}(?!z))*$/


function opts(pairs) {
    return pairs.map(p => ({ value: p[0], label: p[1] }))
}

var BAR_ITEMS = opts([["workspaces", "Áreas de trabalho"], ["system", "CPU, memória e temperatura"],
                      ["clock", "Relógio e música"], ["recording", "Gravação"], ["volume", "Volume"],
                      ["network", "Rede"], ["bluetooth", "Bluetooth"], ["battery", "Bateria"],
                      ["power", "Energia"]])
var POWER_ITEMS = opts([["lock", "Bloquear"], ["logout", "Sair"], ["suspend", "Suspender"],
                        ["reboot", "Reiniciar"], ["poweroff", "Desligar"]])
// Reboot and power off always ask for the second click (settings/powermenu.js):
// only these may be added to it
var POWER_CONFIRM_ITEMS = opts([["lock", "Bloquear"], ["logout", "Sair"], ["suspend", "Suspender"]])

// Idle times (settings/idle.js keeps the same lists): "Nunca" takes the step
// out. A list of choices, never a free number.
var IDLE_TIMES = opts([[0, "Nunca"], [60, "1 min"], [120, "2 min"], [180, "3 min"], [300, "5 min"],
                       [600, "10 min"], [900, "15 min"], [1200, "20 min"], [1800, "30 min"],
                       [2700, "45 min"], [3600, "1 h"], [7200, "2 h"], [10800, "3 h"], [14400, "4 h"]])
var IDLE_WARNINGS = opts([[0, "Sem aviso"], [10, "10 s"], [30, "30 s"], [60, "1 min"]])

// One row per step, the power and the battery choice side by side (pair)
function idleKey(pair, def, label, desc, syn) {
    return { def: def, type: "enum", options: IDLE_TIMES, page: "energia", card: "tempos", pair: pair,
             label: label, desc: desc, syn: syn }
}
function warnKey(pair) {
    return { def: 30, type: "enum", options: IDLE_WARNINGS, page: "energia", card: "tempos", pair: pair,
             label: "Aviso antes de travar", desc: "A tela escurece e conta até travar", syn: ["escurecer", "tela"] }
}
var LOCK_DESC = "Nunca: só trava pelo Super+L, pelo menu e ao fechar a tampa"
var OFF_DESC = "Com a trava ligada, sempre 10 s ou mais depois de travar"

var KEYS = {
    // ── Tema e cores ──
    accent: { def: "padrao", type: "enum", page: "tema", card: "cores", label: "Cor de destaque",
              options: opts([["padrao", "Padrão"], ["red", "Vermelho"], ["green", "Verde"], ["yellow", "Amarelo"],
                             ["blue", "Azul"], ["purple", "Roxo"], ["aqua", "Água"], ["orange", "Laranja"]]),
              control: "swatches", syn: ["cor", "acento", "destaque"] },
    // One for the bar and its panels: they are one shape
    barOpacity: { def: 0.85, type: "real", min: 0.5, max: 1, step: 0.05, format: "percent", page: "tema",
                  card: "superficies", label: "Transparência da barra e dos painéis", desc: "100% é sólida",
                  syn: ["opacidade", "transparente", "painel"] },
    blur: { def: true, type: "bool", page: "tema", card: "superficies", label: "Desfoque atrás dos painéis",
            syn: ["blur", "vidro"] },
    radius: { def: 8, type: "int", min: 0, max: 16, step: 1, unit: "px", page: "tema", card: "superficies",
              label: "Raio dos cantos", desc: "Janelas, barra e painéis", syn: ["arredondado", "cantos"] },
    cursorTheme: { def: "Bibata-Modern-Classic-Right", type: "string", pattern: THEME_NAME, page: "tema",
                   card: "cursor", label: "Tema do cursor", source: "cursorThemes", syn: ["mouse", "ponteiro"] },
    cursorSize: { def: 24, type: "enum", page: "tema", card: "cursor", label: "Tamanho do cursor",
                  options: opts([[20, "20"], [24, "24"], [32, "32"], [48, "48"]]), syn: ["mouse", "ponteiro"] },

    // ── Papel de parede ──
    wallpaper: { def: "~/.config/wallpapers/wallpaper-padrao.png", type: "path", page: "papel", card: "imagem",
                 label: "Imagem", syn: ["fundo", "wallpaper"] },
    wallpaperMonitor: { def: "", type: "string", pattern: OPT_MONITOR, machine: true, page: "papel",
                        card: "ajuste", label: "Tela", source: "monitors", emptyLabel: "Todas as telas",
                        syn: ["monitor"] },
    wallpaperFill: { def: "fill", type: "enum", page: "papel", card: "ajuste", label: "Preenchimento",
                     options: opts([["fill", "Preencher"], ["fit", "Ajustar"], ["center", "Centralizar"],
                                    ["tile", "Lado a lado"]]), syn: ["ajuste", "esticar"] },

    // ── Fontes e animações ──
    fontUi: { def: "Agave Nerd Font Propo", type: "string", pattern: FONT_NAME, page: "fontes", card: "fontes",
              label: "Fonte da interface", source: "fonts", syn: ["letra", "texto"] },
    fontMono: { def: "Agave Nerd Font Mono", type: "string", pattern: FONT_NAME, page: "fontes", card: "fontes",
                label: "Fonte monoespaçada", source: "monoFonts", syn: ["letra", "código"] },
    fontPanels: { def: "Inter", type: "string", pattern: FONT_NAME, page: "fontes", card: "fontes",
                  label: "Fonte dos painéis", desc: "O painel das Configurações", source: "fonts",
                  syn: ["letra", "texto", "painel"] },
    textScale: { def: 100, type: "int", min: 90, max: 130, step: 5, unit: "%", page: "fontes", card: "fontes",
                 label: "Tamanho do texto", syn: ["escala", "zoom"] },
    animSpeed: { def: 1, type: "enum", page: "fontes", card: "animacoes", label: "Velocidade das animações",
                 options: opts([[0, "Sem animação"], [0.7, "Rápida"], [1, "Normal"], [1.4, "Calma"]]),
                 syn: ["movimento", "transição"] },
    reduceMotion: { def: false, type: "bool", page: "fontes", card: "animacoes", label: "Reduzir movimento",
                    syn: ["acessibilidade", "animação"] },

    // ── Barra ──
    barLeft: { def: ["workspaces", "system"], type: "list", options: BAR_ITEMS, page: "barra", card: "itens",
               label: "Itens à esquerda" },
    barCenter: { def: ["clock"], type: "list", options: BAR_ITEMS, page: "barra", card: "itens",
                 label: "Itens no centro" },
    barRight: { def: ["recording", "volume", "network", "bluetooth", "battery", "power"], type: "list",
                options: BAR_ITEMS, page: "barra", card: "itens", label: "Itens à direita" },
    barHidden: { def: [], type: "list", options: BAR_ITEMS, page: "barra", card: "itens", label: "Itens escondidos",
                 syn: ["esconder", "olho"] },
    barPosition: { def: "top", type: "enum", page: "barra", card: "posicao", label: "Posição",
                   options: opts([["top", "Em cima"], ["bottom", "Embaixo"]]) },
    barHeight: { def: 30, type: "int", min: 26, max: 40, step: 2, unit: "px", page: "barra", card: "posicao",
                 label: "Altura" },
    barHideFullscreen: { def: true, type: "bool", page: "barra", card: "posicao", label: "Esconder em tela cheia" },
    clock24h: { def: true, type: "bool", page: "barra", card: "relogio", label: "Relógio de 24 horas",
                syn: ["hora"] },
    clockSeconds: { def: false, type: "bool", page: "barra", card: "relogio", label: "Mostrar os segundos",
                    syn: ["hora"] },
    dateFormat: { def: "ddd dd/MM", type: "enum", page: "barra", card: "relogio", label: "Data",
                  options: opts([["ddd dd/MM", "ter 10/11"], ["dd/MM", "10/11"], ["ddd d MMM", "ter 10 nov"],
                                 ["", "Sem data"]]), syn: ["dia"] },

    // ── Bloqueio e login ──
    lockBlankAfter: { def: 10, type: "enum", page: "bloqueio", card: "tela", label: "Apagar a tela depois de travar",
                      options: opts([[10, "10 s"], [30, "30 s"], [60, "1 min"], [0, "Nunca"]]),
                      syn: ["oled", "desligar a tela"] },
    lockShowMusic: { def: true, type: "bool", page: "bloqueio", card: "tela", label: "Mostrar a música",
                     syn: ["spotify", "player"] },

    // ── Captura e clipboard ──
    captureDir: { def: "~/Pictures/Capturas", type: "path", page: "captura", card: "capturas", label: "Pasta das capturas",
                  syn: ["print", "screenshot"] },
    captureName: { def: "yyyy-MM-dd_HH-mm-ss", type: "string", pattern: FILE_NAME_FORMAT, page: "captura",
                   card: "capturas", label: "Nome dos arquivos", desc: "Data e hora (yyyy, MM, dd, HH, mm, ss)",
                   preview: "fileName" },
    captureDelay: { def: 0, type: "enum", page: "captura", card: "capturas", label: "Atraso padrão",
                    options: opts([[0, "Sem atraso"], [3, "3 s"], [5, "5 s"], [10, "10 s"]]), syn: ["timer"] },
    captureCopy: { def: true, type: "bool", page: "captura", card: "capturas", label: "Copiar para o clipboard" },
    ocrLang: { def: "por+eng", type: "enum", page: "captura", card: "capturas", label: "Idioma do OCR",
               options: opts([["por+eng", "Português e inglês"], ["por", "Português"], ["eng", "Inglês"]]),
               syn: ["texto", "tesseract"] },
    videoDir: { def: "~/Videos/Capturas", type: "path", page: "captura", card: "gravacao", label: "Pasta das gravações",
                syn: ["vídeo"] },
    recordSystemAudio: { def: true, type: "bool", page: "captura", card: "gravacao", label: "Som do sistema",
                         syn: ["áudio"] },
    recordMic: { def: false, type: "bool", page: "captura", card: "gravacao", label: "Microfone", syn: ["áudio"] },
    clipHistory: { def: 100, type: "int", min: 20, max: 500, step: 10, unit: "itens", page: "captura", card: "clipboard",
                   label: "Tamanho do histórico", syn: ["copiar", "colar"] },
    clipImages: { def: true, type: "bool", page: "captura", card: "clipboard", label: "Guardar imagens",
                  syn: ["copiar", "colar"] },

    // ── Energia ──
    // On power suspending is "Nunca" by default (it used to do nothing there)
    idleWarnAc: warnKey("idleWarnBat"),
    idleLockAc: idleKey("idleLockBat", 300, "Travar", LOCK_DESC, ["bloquear"]),
    idleScreenOffAc: idleKey("idleScreenOffBat", 300, "Apagar a tela", OFF_DESC, ["monitor"]),
    idleSuspendAc: idleKey("idleSuspendBat", 0, "Suspender", "", ["dormir"]),
    idleWarnBat: warnKey("idleWarnAc"),
    idleLockBat: idleKey("idleLockAc", 300, "Travar", LOCK_DESC, ["bloquear"]),
    idleScreenOffBat: idleKey("idleScreenOffAc", 300, "Apagar a tela", OFF_DESC, ["monitor"]),
    idleSuspendBat: idleKey("idleSuspendAc", 3600, "Suspender", "", ["dormir"]),
    // The lid always locks (keybinds.lua); "lock" only keeps it from sleeping
    lidAction: { def: "lock-suspend", type: "enum", page: "energia", card: "tampa", label: "Ao fechar a tampa",
                 options: opts([["lock-suspend", "Travar e suspender"], ["lock", "Só travar, sem suspender"]]),
                 desc: "Só travar: fechado na bolsa, o notebook fica ligado, esquenta e gasta bateria. Com monitor externo, só trava",
                 syn: ["notebook"] },
    powerMenuItems: { def: ["lock", "logout", "suspend", "reboot", "poweroff"], type: "list", options: POWER_ITEMS,
                      page: "energia", card: "menu", label: "Itens do menu de energia" },
    powerConfirm: { def: [], type: "list", options: POWER_CONFIRM_ITEMS, page: "energia", card: "menu",
                    label: "Também pedem um segundo clique", desc: "Reiniciar e desligar sempre pedem",
                    syn: ["confirmar"] },

    // ── Monitores (this machine only) ──
    areasTogether: { def: true, type: "bool", machine: true, page: "monitores", card: "areas",
                     label: "Juntas em todas as telas",
                     desc: "Como no Windows: Super+N troca todas as telas juntas. Desligado: cada tela tem as suas",
                     syn: ["areas de trabalho", "workspaces", "telas"] },
    // Kept by the shell (state/AreasState), never a row on the page
    monitorPositions: { def: "", type: "string", pattern: POSITIONS, machine: true, hidden: true, page: "monitores",
                        card: "areas", label: "Posições das telas" },
    barMonitor: { def: "", type: "string", pattern: OPT_MONITOR, machine: true, page: "monitores",
                  card: "barra", label: "Mostrar a barra em", source: "monitors", emptyLabel: "Todas as telas" },
    nightLight: { def: false, type: "bool", machine: true, page: "monitores", card: "luz", label: "Luz noturna",
                  desc: "Liga e desliga sozinha nos horários abaixo", syn: ["hyprsunset", "filtro azul"] },
    nightTemp: { def: 4000, type: "int", min: 2500, max: 6500, step: 100, unit: "K", machine: true, page: "monitores",
                 card: "luz", label: "Temperatura", desc: "6500 K é a cor normal; quanto menor, mais quente" },
    nightStart: { def: "20:00", type: "string", pattern: TIME_HM, machine: true, page: "monitores", card: "luz",
                  label: "Começa às" },
    nightEnd: { def: "06:00", type: "string", pattern: TIME_HM, machine: true, page: "monitores", card: "luz",
                label: "Termina às" },

    // ── Teclado e mouse ──
    kbLayout: { def: "br", type: "string", pattern: /^[a-z]{2,8}$/, machine: true, page: "teclado", card: "teclado",
                label: "Layout do sistema", syn: ["abnt", "idioma"] },
    kbModel: { def: "abnt2", type: "string", pattern: /^$|^[a-z0-9][a-z0-9_]{0,23}$/, machine: true, page: "teclado",
               card: "teclado", label: "Modelo do teclado" },
    repeatDelay: { def: 600, type: "int", min: 150, max: 1000, step: 50, unit: "ms", page: "teclado", card: "teclado",
                   label: "Atraso da repetição" },
    repeatRate: { def: 25, type: "int", min: 10, max: 60, step: 1, unit: "por s", page: "teclado", card: "teclado",
                  label: "Velocidade da repetição" },
    numlockOnStart: { def: false, type: "bool", page: "teclado", card: "teclado", label: "Num Lock ao iniciar" },
    mouseSensitivity: { def: 0, type: "real", min: -1, max: 1, step: 0.1, page: "teclado", card: "mouse",
                        label: "Velocidade do mouse" },
    mouseAccel: { def: "adaptive", type: "enum", page: "teclado", card: "mouse", label: "Aceleração",
                  options: opts([["adaptive", "Adaptativa"], ["flat", "Plana"]]) },
    mouseNatural: { def: false, type: "bool", page: "teclado", card: "mouse", label: "Rolagem natural" },
    mouseLeftHanded: { def: false, type: "bool", page: "teclado", card: "mouse", label: "Mão esquerda",
                       syn: ["canhoto"] },
    focusFollowsMouse: { def: true, type: "bool", page: "teclado", card: "mouse", label: "Foco segue o mouse" },
    tapToClick: { def: true, type: "bool", page: "teclado", card: "touchpad", label: "Tocar para clicar" },
    twoFingerScroll: { def: true, type: "bool", page: "teclado", card: "touchpad", label: "Rolar com dois dedos" },
    tapAndDrag: { def: true, type: "bool", page: "teclado", card: "touchpad", label: "Tocar e arrastar" },
    touchpadNatural: { def: true, type: "bool", page: "teclado", card: "touchpad", label: "Rolagem natural" },
    disableWhileTyping: { def: true, type: "bool", page: "teclado", card: "touchpad", label: "Desligar ao digitar" },
    disableWithMouse: { def: false, type: "bool", page: "teclado", card: "touchpad",
                        label: "Desligar com mouse externo" },
    touchpadSensitivity: { def: 0, type: "real", min: -1, max: 1, step: 0.1, page: "teclado", card: "touchpad",
                           label: "Velocidade do touchpad" },

    // ── Apps padrão (this machine only: "" is the system's choice) ──
    appBrowser: appKey("Navegador", ["internet", "web"]),
    appFiles: appKey("Arquivos", ["pastas", "explorador"]),
    appTerminal: appKey("Terminal", ["console"]),
    appImages: appKey("Imagens", ["fotos"]),
    appVideos: appKey("Vídeos", ["filmes"]),
    appMusic: appKey("Músicas", ["áudio"]),
    appText: appKey("Texto", ["editor"]),
    appPdf: appKey("PDF", ["documentos"])
}

function appKey(label, syn) {
    return { def: "", type: "string", pattern: OPT_DESKTOP_ID, machine: true, page: "apps",
             card: "apps", label: label, syn: syn }
}

var PAGE_IDS = PAGES.map(p => p.id)

// Keys that share a row (pair): each one names the other, both exist, with
// the same type, page and card. Returns the problems found ([] when fine);
// read by the tests and by the page, which shows a broken pair as two rows.
function pairProblems(keys) {
    const out = []
    for (const [k, spec] of Object.entries(keys)) {
        if (spec.pair === undefined)
            continue
        const other = keys[spec.pair]
        if (!other)
            out.push(`${k}: par ${spec.pair} não existe`)
        else if (other.pair !== k)
            out.push(`${k}: ${spec.pair} não aponta de volta`)
        else if (other.type !== spec.type || other.page !== spec.page || other.card !== spec.card)
            out.push(`${k}: ${spec.pair} com outro tipo, página ou grupo`)
    }
    return out
}
