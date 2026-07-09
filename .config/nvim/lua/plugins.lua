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
    vim.keymap.set("n", "<leader>e", ":Neotree toggle<CR>", {})
  end,
}, {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("lualine").setup({
      options = {
        theme = "gruvbox",
        section_separators = "",
        component_separators = "",
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
      auto_enable = true,
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
    vim.keymap.set("n", "<leader>nm", "<cmd>Neominimap toggle<CR>", { desc = "Toggle minimap" })
    vim.keymap.set("n", "<leader>nb", "<cmd>Neominimap bufToggle<CR>", { desc = "Toggle minimap (buffer)" })
    vim.keymap.set("n", "<leader>nf", "<cmd>Neominimap focus<CR>", { desc = "Focus minimap" })
  end,
},
}
