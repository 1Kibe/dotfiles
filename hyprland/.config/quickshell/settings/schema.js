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

// ── Pages, in the order of the sidebar ──
var PAGES = [
    { id: "tema", group: "Aparência", icon: "󰏘", name: "Tema e cores", sub: "Destaque, transparência, cantos e cursor" },
    { id: "papel", group: "Aparência", icon: "󰸉", name: "Papel de parede", sub: "Imagem e preenchimento" },
    { id: "fontes", group: "Aparência", icon: "󰛖", name: "Fontes e animações", sub: "Fontes, tamanho do texto e velocidade" },
    { id: "barra", group: "Shell", icon: "󰕮", name: "Barra", sub: "Itens, posição e relógio" },
    { id: "bloqueio", group: "Shell", icon: "󰌾", name: "Bloqueio e login", sub: "Tela apagada e música" },
    { id: "captura", group: "Shell", icon: "󰄀", name: "Captura e clipboard", sub: "Pastas, OCR, gravação e histórico" },
    { id: "energia", group: "Sistema", icon: "󰂄", name: "Energia", sub: "Tempos, tampa e menu de energia" },
    { id: "monitores", group: "Sistema", icon: "󰍹", name: "Monitores", sub: "Barra e luz noturna" },
    { id: "teclado", group: "Sistema", icon: "󰌌", name: "Teclado e mouse", sub: "Layout, repetição, mouse e touchpad" },
    { id: "atalhos", group: "Sistema", icon: "󰘳", name: "Atalhos", sub: "Lista dos atalhos" },
    { id: "apps", group: "Sistema", icon: "󰀻", name: "Apps padrão", sub: "Navegador, arquivos, terminal e outros" },
    { id: "sobre", group: "Sistema", icon: "󰋼", name: "Sobre", sub: "Versão, sistema e suas configurações" }
]

// ── Cards of each page; `component` names a special card (settings/cards/) ──
var CARDS = {
    tema: [{ id: "preview", title: "Tema atual", component: "ThemePreview" }, { id: "cores", title: "Cores" },
           { id: "superficies", title: "Superfícies" }, { id: "cursor", title: "Cursor" }],
    papel: [{ id: "imagem", title: "Imagem", component: "WallpaperGallery" }, { id: "ajuste", title: "Ajuste" }],
    fontes: [{ id: "fontes", title: "Fontes" }, { id: "animacoes", title: "Animações" },
             { id: "previa", title: "Prévia da animação", component: "AnimationPreview" }],
    barra: [{ id: "itens", title: "Itens", component: "BarItems" }, { id: "posicao", title: "Posição" },
            { id: "relogio", title: "Relógio" }],
    bloqueio: [{ id: "tela", title: "Tela" }, { id: "seguranca", title: "Segurança", component: "LockSecurity" }],
    captura: [{ id: "capturas", title: "Capturas" }, { id: "gravacao", title: "Gravação" },
              { id: "clipboard", title: "Clipboard" }],
    energia: [{ id: "tomada", title: "Na tomada" }, { id: "bateria", title: "Na bateria" }, { id: "tampa", title: "Tampa" },
              { id: "menu", title: "Menu de energia" }],
    monitores: [{ id: "arranjo", title: "Arranjo", component: "MonitorLayout" }, { id: "barra", title: "Barra" },
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
var MONITOR_NAME = /^[A-Za-z0-9][A-Za-z0-9._-]{0,31}$/
var OPT_MONITOR = /^$|^[A-Za-z0-9][A-Za-z0-9._-]{0,31}$/
var DESKTOP_ID = /^[A-Za-z0-9][A-Za-z0-9._-]{0,95}\.desktop$/
var OPT_DESKTOP_ID = /^$|^[A-Za-z0-9][A-Za-z0-9._-]{0,95}\.desktop$/
var TIME_HM = /^([01][0-9]|2[0-3]):[0-5][0-9]$/
var FILE_NAME_FORMAT = /^[yMdHhmsz][yMdHhmsz_.-]{0,39}$/

// Idle times: 0 is "Nunca"
var IDLE = { min: 0, max: 14400, step: 10 }

function opts(pairs) {
    return pairs.map(p => ({ value: p[0], label: p[1] }))
}

var BAR_ITEMS = opts([["workspaces", "Áreas de trabalho"], ["system", "CPU, memória e temperatura"],
                      ["clock", "Relógio e música"], ["recording", "Gravação"], ["volume", "Volume"],
                      ["network", "Rede"], ["bluetooth", "Bluetooth"], ["battery", "Bateria"],
                      ["power", "Energia"]])
var POWER_ITEMS = opts([["lock", "Bloquear"], ["logout", "Sair"], ["suspend", "Suspender"],
                        ["reboot", "Reiniciar"], ["poweroff", "Desligar"]])

function idleKey(page, card, def, label, syn) {
    return { def: def, type: "int", min: IDLE.min, max: IDLE.max, step: IDLE.step, page: page, card: card,
             label: label, desc: "Em segundos; 0 é nunca", syn: syn }
}

var KEYS = {
    // ── Tema e cores ──
    accent: { def: "padrao", type: "enum", page: "tema", card: "cores", label: "Cor de destaque",
              options: opts([["padrao", "Padrão"], ["red", "Vermelho"], ["green", "Verde"], ["yellow", "Amarelo"],
                             ["blue", "Azul"], ["purple", "Roxo"], ["aqua", "Água"], ["orange", "Laranja"]]),
              syn: ["cor", "acento", "destaque"] },
    // One for the bar and its panels: they are one shape (Ryan, 2026-11-11)
    barOpacity: { def: 0.85, type: "real", min: 0.5, max: 1, step: 0.05, page: "tema", card: "superficies",
                  label: "Transparência da barra e dos painéis", desc: "1 é sólida",
                  syn: ["opacidade", "transparente", "painel"] },
    blur: { def: true, type: "bool", page: "tema", card: "superficies", label: "Desfoque atrás dos painéis",
            syn: ["blur", "vidro"] },
    radius: { def: 8, type: "int", min: 0, max: 16, step: 1, page: "tema", card: "superficies",
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
    textScale: { def: 100, type: "int", min: 90, max: 130, step: 5, page: "fontes", card: "fontes",
                 label: "Tamanho do texto", desc: "Em %", syn: ["escala", "zoom"] },
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
    barHeight: { def: 30, type: "int", min: 26, max: 40, step: 2, page: "barra", card: "posicao", label: "Altura" },
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
                   card: "capturas", label: "Nome dos arquivos", desc: "Data e hora (yyyy, MM, dd, HH, mm, ss)" },
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
    clipHistory: { def: 100, type: "int", min: 20, max: 500, step: 10, page: "captura", card: "clipboard",
                   label: "Tamanho do histórico", syn: ["copiar", "colar"] },
    clipImages: { def: true, type: "bool", page: "captura", card: "clipboard", label: "Guardar imagens",
                  syn: ["copiar", "colar"] },

    // ── Energia (0 = nunca) ──
    idleDimAc: idleKey("energia", "tomada", 270, "Escurecer", ["tela"]),
    idleLockAc: idleKey("energia", "tomada", 300, "Travar", ["bloquear"]),
    idleScreenOffAc: idleKey("energia", "tomada", 310, "Apagar a tela", ["monitor"]),
    idleSuspendAc: idleKey("energia", "tomada", 3600, "Suspender", ["dormir"]),
    idleDimBat: idleKey("energia", "bateria", 270, "Escurecer", ["tela"]),
    idleLockBat: idleKey("energia", "bateria", 300, "Travar", ["bloquear"]),
    idleScreenOffBat: idleKey("energia", "bateria", 310, "Apagar a tela", ["monitor"]),
    idleSuspendBat: idleKey("energia", "bateria", 3600, "Suspender", ["dormir"]),
    lidAction: { def: "lock-suspend", type: "enum", page: "energia", card: "tampa", label: "Ao fechar a tampa",
                 options: opts([["lock-suspend", "Travar e suspender"], ["lock", "Só travar"], ["nothing", "Nada"]]),
                 desc: "Com monitor externo, só trava", syn: ["notebook"] },
    batteryConservation: { def: false, type: "bool", machine: true, page: "energia", card: "bateria",
                           label: "Conservação da bateria", desc: "Carrega até cerca de 60%", syn: ["lenovo"] },
    powerMenuItems: { def: ["lock", "logout", "suspend", "reboot", "poweroff"], type: "list", options: POWER_ITEMS,
                      page: "energia", card: "menu", label: "Itens do menu de energia" },
    powerConfirm: { def: ["reboot", "poweroff"], type: "list", options: POWER_ITEMS, page: "energia", card: "menu",
                    label: "Pedem um segundo clique", syn: ["confirmar"] },

    // ── Monitores (this machine only) ──
    barMonitor: { def: "", type: "string", pattern: OPT_MONITOR, machine: true, page: "monitores",
                  card: "barra", label: "Tela da barra", desc: "Vazio é todas" },
    nightLight: { def: false, type: "bool", machine: true, page: "monitores", card: "luz", label: "Luz noturna",
                  syn: ["hyprsunset", "filtro azul"] },
    nightTemp: { def: 4000, type: "int", min: 2500, max: 6500, step: 100, machine: true, page: "monitores", card: "luz",
                 label: "Temperatura", desc: "Em kelvin" },
    nightStart: { def: "20:00", type: "string", pattern: TIME_HM, machine: true, page: "monitores", card: "luz",
                  label: "Começa às" },
    nightEnd: { def: "06:00", type: "string", pattern: TIME_HM, machine: true, page: "monitores", card: "luz",
                label: "Termina às" },

    // ── Teclado e mouse ──
    kbLayout: { def: "br", type: "string", pattern: /^[a-z]{2,8}$/, machine: true, page: "teclado", card: "teclado",
                label: "Layout do sistema", syn: ["abnt", "idioma"] },
    kbModel: { def: "abnt2", type: "string", pattern: /^$|^[a-z0-9][a-z0-9_]{0,23}$/, machine: true, page: "teclado",
               card: "teclado", label: "Modelo do teclado" },
    repeatDelay: { def: 600, type: "int", min: 150, max: 1000, step: 50, page: "teclado", card: "teclado",
                   label: "Atraso da repetição", desc: "Em ms" },
    repeatRate: { def: 25, type: "int", min: 10, max: 60, step: 1, page: "teclado", card: "teclado",
                  label: "Velocidade da repetição", desc: "Por segundo" },
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
