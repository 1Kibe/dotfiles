local alpha = require("alpha")
local dashboard = require("alpha.themes.dashboard")

local icons = {
  file = " ",
  search = " ",
  recent = " ",
  explore = " ",
  config = "  ",
  quit = " ",
}

-- =========================
-- ASCII ART 1 (TOPO)
-- =========================
local left_art = {
  "                                                        ",
  "                                                        ",
  "                                                        ",
  "              ⣴⣶⣤⡤⠦⣤⣀⣤⠆     ⣈⣭⣿⣶⣿⣦⣼⣆                    ",
  "               ⠉⠻⢿⣿⠿⣿⣿⣶⣦⠤⠄⡠⢾⣿⣿⡿⠋⠉⠉⠻⣿⣿⡛⣦                 ",
  "                     ⠈⢿⣿⣟⠦ ⣾⣿⣿⣷    ⠻⠿⢿⣿⣧⣄               ",
  "                      ⣸⣿⣿⢧ ⢻⠻⣿⣿⣷⣄⣀⠄⠢⣀⡀⠈⠙⠿⠄              ",
  "                     ⢠⣿⣿⣿⠈    ⣻⣿⣿⣿⣿⣿⣿⣿⣛⣳⣤⣀⣀             ",
  "              ⢠⣧⣶⣥⡤⢄ ⣸⣿⣿⠘  ⢀⣴⣿⣿⡿⠛⣿⣿⣧⠈⢿⠿⠟⠛⠻⠿⠄            ",
  "             ⣰⣿⣿⠛⠻⣿⣿⡦⢹⣿⣷   ⢊⣿⣿⡏  ⢸⣿⣿⡇ ⢀⣠⣄⣾⠄             ",
  "            ⣠⣿⠿⠛ ⢀⣿⣿⣷⠘⢿⣿⣦⡀ ⢸⢿⣿⣿⣄ ⣸⣿⣿⡇⣪⣿⡿⠿⣿⣷⡄            ",
  "            ⠙⠃   ⣼⣿⡟  ⠈⠻⣿⣿⣦⣌⡇⠻⣿⣿⣷⣿⣿⣿ ⣿⣿⡇ ⠛⠻⢷⣄           ",
  "                 ⢻⣿⣿⣄   ⠈⠻⣿⣿⣿⣷⣿⣿⣿⣿⣿⡟ ⠫⢿⣿⡆               ",
  "                  ⠻⣿⣿⣿⣿⣶⣶⣾⣿⣿⣿⣿⣿⣿⣿⣿⡟⢀⣀⣤⣾⡿⠃               ",
  "                                                        ",
}

-- =========================
-- ASCII ART 2 (BAIXO)
-- =========================
local right_art = {
  [[                                                        ]],
  [[    ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗  ]],
  [[    ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║  ]],
  [[    ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║  ]],
  [[    ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║  ]],
  [[    ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║  ]],
  [[    ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝  ]],
  [[                                                        ]],
}

-- =========================
-- JUNÇÃO VERTICAL
-- =========================
local function concat_ascii(top, bottom)
  local result = {}

  for _, line in ipairs(top) do
    table.insert(result, line)
  end

  table.insert(result, "") -- espaço entre artes

  for _, line in ipairs(bottom) do
    table.insert(result, line)
  end

  return result
end

-- HEADER FINAL
dashboard.section.header.val = concat_ascii(left_art, right_art)

-- =========================
-- BOTÕES
-- =========================
dashboard.section.buttons.val = {
  dashboard.button("n", "  Novo arquivo",           ":ene <BAR> startinsert<CR>"),
  dashboard.button("f", "  Buscar arquivo",         ":Telescope find_files<CR>"),
  dashboard.button("g", "  Buscar texto",           ":Telescope live_grep<CR>"),
  dashboard.button("e", "  Explorador de arquivos", ":Neotree toggle<CR>"),
  dashboard.button("r", "  Arquivos recentes",      ":Telescope oldfiles<CR>"),
  dashboard.button("c", "  Editar config",          ":e ~/.config/nvim/lua/dashboard.lua<CR>"),
  dashboard.button("q", "  Sair",                   ":qa<CR>"),
}

-- =========================
-- RECENTES
-- =========================
local recent_files = {
  type = "group",
  val = function()
    local recent = {}
    local count = 0

    for _, file in ipairs(vim.v.oldfiles) do
      if count >= 3 then break end

      if vim.fn.filereadable(file) == 1 then
        local name = vim.fn.fnamemodify(file, ":~:.")
        local btn = dashboard.button(tostring(count), "📄  " .. name, ":e " .. file .. "<CR>")
        table.insert(recent, btn)
        count = count + 1
      end
    end

    return recent
  end,
  opts = { spacing = 1 },
}

-- =========================
-- FOOTER
-- =========================
dashboard.section.footer.val = {
  "⚡ Neovim carregado em "
    .. vim.fn.reltimefloat(vim.fn.reltime(vim.g.start_time))
    .. "ms",
}

-- =========================
-- LAYOUT
-- =========================
dashboard.config.layout = {
  { type = "padding", val = 1 },
  dashboard.section.header,
  { type = "padding", val = 1 },
  dashboard.section.buttons,
  { type = "padding", val = 1 },
  recent_files,
  { type = "padding", val = 1 },
  dashboard.section.footer,
}

dashboard.config.opts.noautocmd = true
alpha.setup(dashboard.config)
