return {
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
    config = function()
      require("gruvbox").setup({
        contrast = "hard",
        transparent_mode = false,
        italics = true,
      })
      vim.cmd.colorscheme("gruvbox")
    end,
  },
  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("dashboard")
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    branch = "master",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-ui-select.nvim",
    },
    config = function()
      local builtin = require("telescope.builtin")
      require("telescope").setup({
        defaults = {
          path_display = { filename_first = { reverse_directories = false } },
        },
        extensions = {
          ["ui-select"] = {
            require("telescope.themes").get_dropdown(),
          },
        },
      })
      require("telescope").load_extension("ui-select")
      vim.keymap.set("n", "<leader>ff", builtin.find_files, {})
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, {})
      vim.keymap.set("n", "<leader>fb", builtin.buffers, {})
    end,
  }, {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = "BufReadPost",
  config = function()
    require("nvim-treesitter").setup({
      ensure_installed = { "lua", "java", "javascript", "typescript", "html", "css", "json", "bash" },
      highlight = { enable = true },
      indent = { enable = true },
    })
  end,
}, {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  config = function()
    require("neo-tree").setup({
      filesystem = {
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_hidden = false,
        },
      },
    })
    vim.keymap.set("n", "<leader>e", ":Neotree toggle<CR>", {})
  end,
}, {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local function term_count()
      local ok, tt = pcall(require, "toggleterm.terminal")
      if not ok then return "" end
      local count = #tt.get_all(true)
      if count == 0 then return "" end
      return string.format(" %d term%s", count, count > 1 and "s" or "")
    end

    require("lualine").setup({
      options = {
        theme = "gruvbox",
        section_separators = "",
        component_separators = "",
      },
      sections = {
        lualine_x = { term_count, "encoding", "fileformat", "filetype" },
      },
    })
  end,
}, {
  "williamboman/mason.nvim",
  config = function()
    require("mason").setup()
  end,
}, {
  "williamboman/mason-lspconfig.nvim",
  dependencies = { "williamboman/mason.nvim" },
  config = function()
    require("mason-lspconfig").setup({
      ensure_installed = { "lua_ls", "jdtls" }
    })
  end,
}, {
  "WhoIsSethDaniel/mason-tool-installer.nvim",
  dependencies = { "williamboman/mason.nvim" },
  opts = {
    ensure_installed = { "prettier", "stylua", "shfmt", "ruff", "clang-format", "taplo", "google-java-format", "php-cs-fixer" },
  },
}, {
  "neovim/nvim-lspconfig",
  dependencies = { "williamboman/mason-lspconfig.nvim" },
  config = function()
    local servers = { "lua_ls", "jdtls", "ts_ls", "html", "cssls", "eslint" }
    vim.keymap.set('n', 'K', function() vim.lsp.buf.hover() end, {})
    vim.keymap.set('n', 'gd', function() vim.lsp.buf.definition() end, {})
    vim.keymap.set({ 'n' }, '<leader>ca', function() vim.lsp.buf.code_action() end, {})
    vim.keymap.set('n', '<leader>f', function()
      require("conform").format({ async = true, timeout_ms = 5000 })
    end, {})
    for _, server in ipairs(servers) do
      vim.lsp.config(server, {})
      vim.lsp.enable(server)
    end
  end,
}, {
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  config = function()
    require("nvim-autopairs").setup()
  end,
}, {
  "numToStr/Comment.nvim",
  event = "BufReadPost",
  config = function()
    require("Comment").setup()
  end
}, {
  "lewis6991/gitsigns.nvim",
  event = "BufReadPost",
  config = function()
    require("gitsigns").setup()
  end,
}, {
  "lukas-reineke/indent-blankline.nvim",
  event = "BufReadPost",
  main = "ibl",
  config = function()
    require("ibl").setup()
  end,
}, {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  config = function()
    require("conform").setup({
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_format" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        rust = { "rustfmt" },
        go = { "gofumpt" },
        nix = { "alejandra" },
        toml = { "taplo" },
        java = { "google-java-format" },
        php = { "php-cs-fixer" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        javascriptreact = { "prettier" },
        typescriptreact = { "prettier" },
        css = { "prettier" },
        html = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        bash = { "shfmt" },
      },
      format_on_save = false,
    })
  end,
}, {
  "hrsh7th/nvim-cmp",
  event = "InsertEnter",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "L3MON4D3/LuaSnip",
    "saadparwaiz1/cmp_luasnip",
  },
  config = function()
    local cmp = require("cmp")
    local luasnip = require("luasnip")

    cmp.setup({
      snippet = {
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },
      mapping = cmp.mapping.preset.insert({
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<CR>"] = cmp.mapping.confirm({ select = true }),
        ["<Tab>"] = cmp.mapping.select_next_item(),
        ["<S-Tab>"] = cmp.mapping.select_prev_item(),
        ["<C-e>"] = cmp.mapping.abort(),
      }),
      sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "luasnip" },
        { name = "buffer" },
        { name = "path" },
      }),
    })
  end,
}, {
  "Isrothy/neominimap.nvim",
  version = "v3.x.x",
  lazy = false,
  init = function()
    vim.opt.wrap = false
    vim.opt.sidescrolloff = 36
    vim.g.neominimap = {
      auto_enable = false,
      layout = "split",
      split = {
        direction = "right",
        width = 20,
        close_if_last_window = true,
      },
      exclude_filetypes = { "help", "alpha", "neo-tree", "dashboard" },
      exclude_buftypes = { "nofile", "nowrite", "quickfix", "terminal", "prompt" },
      click = { enabled = true, auto_switch_focus = false },
      diagnostic = {
        enabled = true,
        severity = vim.diagnostic.severity.HINT,
        mode = "line",
        priority = {
          ERROR = 100,
          WARN = 90,
          INFO = 80,
          HINT = 70,
        },
        icon = {
          ERROR = "󰅚 ",
          WARN = "󰀪 ",
          INFO = "󰋽 ",
          HINT = "󰌶 ",
        },
      },
      git = {
        enabled = true,
        mode = "sign",
        priority = 6,
        icon = {
          add = "+ ",
          change = "~ ",
          delete = "- ",
        },
      },
      search = {
        enabled = true,
        mode = "line",
        priority = 20,
        icon = "󰱽 ",
      },
      mark = {
        enabled = true,
        mode = "icon",
        priority = 10,
        key = "m",
        show_builtins = false,
      },
      treesitter = { enabled = true, priority = 200 },
    }
    vim.keymap.set("n", "<leader>nm", "<cmd>Neominimap Toggle<CR>", { desc = "Toggle minimap" })
    vim.keymap.set("n", "<leader>nb", "<cmd>Neominimap BufToggle<CR>", { desc = "Toggle minimap (buffer)" })
    vim.keymap.set("n", "<leader>nf", "<cmd>Neominimap Focus<CR>", { desc = "Focus minimap" })

    local group = vim.api.nvim_create_augroup("NeominimapAutoOpen", { clear = true })
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
      group = group,
      once = true,
      callback = function(args)
        local bt = vim.bo[args.buf].buftype
        local ft = vim.bo[args.buf].filetype
        local skip_ft = { alpha = true, dashboard = true, ["neo-tree"] = true, help = true, TelescopePrompt = true }
        if bt ~= "" or skip_ft[ft] then
          return
        end
        vim.schedule(function() vim.cmd("Neominimap Enable") end)
      end,
    })
  end,
}, {
  "mg979/vim-visual-multi",
  branch = "master",
  event = "BufReadPost",
  init = function()
    vim.g.VM_maps = {
      ["Find Under"] = "<C-n>",
      ["Find Subword Under"] = "<C-n>",
      ["Select All"] = "<C-A>",
      ["Add Cursor Down"] = "<C-Down>",
      ["Add Cursor Up"] = "<C-Up>",
      ["Skip Region"] = "<C-x>",
      ["Remove Region"] = "<C-p>",
    }
    vim.g.VM_theme = "iceblue"
    vim.g.VM_show_warnings = 0
  end,
}, {
  "nvim-pack/nvim-spectre",
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = "Spectre",
  keys = {
    { "<leader>S",  function() require("spectre").toggle() end,                             desc = "Spectre: toggle (search & replace no projeto)" },
    { "<leader>sw", function() require("spectre").open_visual({ select_word = true }) end,  desc = "Spectre: buscar palavra sob cursor" },
    { "<leader>sw", function() require("spectre").open_visual() end,                        mode = "v",                                                 desc = "Spectre: buscar seleção" },
    { "<leader>sp", function() require("spectre").open_file_search({ select_word = true }) end, desc = "Spectre: buscar palavra no arquivo atual" },
  },
  config = function()
    require("spectre").setup()
  end,
}, {
  "tpope/vim-fugitive",
  cmd = { "Git", "G", "Gdiffsplit", "Gvdiffsplit", "Gedit", "Gread", "Gwrite", "Gblame" },
  keys = {
    { "<leader>gs", "<cmd>Git<cr>",       desc = "Git status (fugitive)" },
    { "<leader>gb", "<cmd>Git blame<cr>", desc = "Git blame" },
    { "<leader>gl", "<cmd>Git log<cr>",   desc = "Git log" },
  },
}, {
  "sindrets/diffview.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewToggleFiles" },
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>",        desc = "Diffview: abrir diff" },
    { "<leader>gh", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview: histórico do repo" },
    { "<leader>gf", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview: histórico do arquivo atual" },
    { "<leader>gc", "<cmd>DiffviewClose<cr>",       desc = "Diffview: fechar" },
  },
}, {
  "folke/which-key.nvim",
  event = "VeryLazy",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300
  end,
  opts = {
    preset = "modern",
  },
}, {
  "folke/trouble.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  cmd = "Trouble",
  keys = {
    { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",                             desc = "Trouble: todos diagnostics" },
    { "<leader>xd", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",                desc = "Trouble: diagnostics do buffer" },
    { "<leader>xs", "<cmd>Trouble symbols toggle focus=false<cr>",                     desc = "Trouble: símbolos do arquivo" },
    { "<leader>xl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",      desc = "Trouble: definições/refs LSP" },
    { "<leader>xL", "<cmd>Trouble loclist toggle<cr>",                                 desc = "Trouble: location list" },
    { "<leader>xQ", "<cmd>Trouble qflist toggle<cr>",                                  desc = "Trouble: quickfix list" },
  },
  opts = {},
}, {
  "akinsho/toggleterm.nvim",
  version = "*",
  event = "VeryLazy",
  config = function()
    local is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
    local shell = is_windows and (vim.fn.executable("pwsh") == 1 and "pwsh" or "powershell") or vim.o.shell

    -- lookup pra dar nome bonito aos terminais criados via :NToggleTerm
    local term_display_names = {
      [1] = "Shell 1",
      [2] = "Shell 2",
      [3] = "Shell 3",
    }

    require("toggleterm").setup({
      open_mapping = [[<c-\>]],
      direction = "float",
      float_opts = { border = "curved" },
      shade_terminals = true,
      shading_factor = 2,
      start_in_insert = true,
      insert_mappings = true,
      terminal_mappings = true,
      persist_size = true,
      persist_mode = true,
      hide_numbers = true,
      shell = shell,
      winbar = {
        enabled = true,
        name_formatter = function(term)
          local name = term.display_name
          if not name or name == "" then name = term_display_names[term.id] end
          if name and name ~= "" then
            return string.format("  [%d] %s", term.id, name)
          end
          return string.format("  Terminal %d", term.id)
        end,
      },
    })

    local Terminal = require("toggleterm.terminal").Terminal

    local function close_current_terminal()
      local buf = vim.api.nvim_get_current_buf()
      if vim.bo[buf].buftype == "terminal" then
        vim.cmd("bdelete! " .. buf)
      else
        vim.notify("Nenhum terminal ativo no buffer atual", vim.log.levels.INFO)
      end
    end

    local function close_all_terminals()
      local all = require("toggleterm.terminal").get_all(true)
      for _, term in pairs(all) do
        term:shutdown()
      end
      vim.notify(string.format("%d terminal(is) fechado(s)", #all), vim.log.levels.INFO)
    end

    -- keymaps
    vim.keymap.set("n", "<leader>tf", "<cmd>ToggleTerm direction=float<cr>",             { desc = "Terminal: flutuante" })
    vim.keymap.set("n", "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>",        { desc = "Terminal: horizontal" })
    vim.keymap.set("n", "<leader>tv", "<cmd>ToggleTerm direction=vertical size=80<cr>",  { desc = "Terminal: vertical" })
    vim.keymap.set("n", "<leader>ts", "<cmd>TermSelect<cr>",                             { desc = "Terminal: escolher da lista" })
    vim.keymap.set("n", "<leader>t1", "<cmd>1ToggleTerm direction=float<cr>",            { desc = "Terminal 1 (Shell 1)" })
    vim.keymap.set("n", "<leader>t2", "<cmd>2ToggleTerm direction=float<cr>",            { desc = "Terminal 2 (Shell 2)" })
    vim.keymap.set("n", "<leader>t3", "<cmd>3ToggleTerm direction=float<cr>",            { desc = "Terminal 3 (Shell 3)" })
    vim.keymap.set("n", "<leader>tq", close_current_terminal,                            { desc = "Terminal: fechar atual" })
    vim.keymap.set("n", "<leader>tQ", close_all_terminals,                               { desc = "Terminal: fechar TODOS" })

    -- atalhos DENTRO do terminal
    function _G.set_terminal_keymaps()
      local opts = { buffer = 0 }
      vim.keymap.set("t", "<esc>",   [[<C-\><C-n>]],           opts)
      vim.keymap.set("t", "jk",      [[<C-\><C-n>]],           opts)
      vim.keymap.set("t", "<C-h>",   [[<Cmd>wincmd h<CR>]],    opts)
      vim.keymap.set("t", "<C-j>",   [[<Cmd>wincmd j<CR>]],    opts)
      vim.keymap.set("t", "<C-k>",   [[<Cmd>wincmd k<CR>]],    opts)
      vim.keymap.set("t", "<C-l>",   [[<Cmd>wincmd l<CR>]],    opts)
      vim.keymap.set("t", "<C-w>",   [[<C-\><C-n><C-w>]],      opts)
    end
    vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")

    -- Lazygit dedicado (se estiver instalado no sistema)
    if vim.fn.executable("lazygit") == 1 then
      local lazygit = Terminal:new({
        cmd = "lazygit",
        display_name = "Lazygit",
        dir = "git_dir",
        direction = "float",
        float_opts = { border = "double" },
        hidden = true,
      })
      vim.keymap.set("n", "<leader>tg", function() lazygit:toggle() end, { desc = "Terminal: Lazygit" })
    end
  end,
}, {
  "akinsho/bufferline.nvim",
  version = "*",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "BufReadPost",
  keys = {
    { "]b",         "<cmd>BufferLineCycleNext<cr>",   desc = "Buffer: próximo" },
    { "[b",         "<cmd>BufferLineCyclePrev<cr>",   desc = "Buffer: anterior" },
    { "<leader>bd", "<cmd>bdelete<cr>",               desc = "Buffer: fechar atual" },
    { "<leader>bo", "<cmd>BufferLineCloseOthers<cr>", desc = "Buffer: fechar outros" },
    { "<leader>bp", "<cmd>BufferLinePick<cr>",        desc = "Buffer: escolher (letra)" },
  },
  opts = {
    options = {
      mode = "buffers",
      diagnostics = "nvim_lsp",
      show_buffer_close_icons = true,
      show_close_icon = false,
      offsets = {
        { filetype = "neo-tree", text = "Explorer", separator = true, text_align = "left" },
      },
    },
  },
}, {
  "NeogitOrg/neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "sindrets/diffview.nvim",
    "nvim-telescope/telescope.nvim",
  },
  cmd = "Neogit",
  keys = {
    { "<leader>gg", "<cmd>Neogit<cr>", desc = "Neogit: abrir interface git" },
  },
  config = function()
    require("neogit").setup({
      integrations = {
        diffview = true,
        telescope = true,
      },
    })
  end,
},
}
