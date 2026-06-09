# arch+xfce — Dotfiles

Configurações pessoais para **Arch Linux + XFCE + i3**, versionadas para fácil replicação em qualquer máquina.

## 🧰 O que está incluído

| Ferramenta | Descrição |
|---|---|
| **i3** | Window manager (com i3status, i3lock, xss-lock) |
| **Alacritty** | Terminal emulator (com tema Gruvbox + FiraCode Nerd Font) |
| **Neovim** | Editor completo com LSP, autocomplete, formatters, file-tree, dashboard e IA |
| **Rofi** | Application launcher (tema gruvbox-dark) |
| **Thunar** | File manager (com ações customizadas e atalhos) |
| **XFCE4** | Screenshooter, desktop icons e helpers |
| **Pavucontrol** | Controle de áudio PulseAudio/PipeWire |
| **GTK 3.0** | Bookmarks e configurações |

### Plugins do Neovim

Gerenciados via **lazy.nvim** (bootstrap automático):

- `gruvbox.nvim` — tema Gruvbox dark (contraste hard)
- `alpha-nvim` — dashboard inicial com ASCII art
- `telescope.nvim` — busca fuzzy de arquivos/texto/buffers
- `nvim-treesitter` — syntax highlighting avançado
- `neo-tree.nvim` — explorador de arquivos lateral
- `lualine.nvim` — statusline elegante
- `mason.nvim` / `mason-lspconfig.nvim` — gerência de LSPs
- `nvim-lspconfig` — configuração nativa de LSPs
- `nvim-cmp` — autocomplete inteligente
- `conform.nvim` — formatação de código
- `nvim-autopairs` — fecha pares automaticamente
- `Comment.nvim` — atalhos de comentário
- `gitsigns.nvim` — indicadores de git no gutter
- `indent-blankline.nvim` — guias de indentação
- `avante.nvim` — chat com IA integrado (DeepSeek)

### Formatters suportados (via conform.nvim)

| Linguagem | Formatter |
|---|---|
| Lua | stylua |
| Python | ruff |
| C/C++ | clang-format |
| Rust | rustfmt |
| Go | gofumpt |
| Nix | alejandra |
| TOML | taplo |
| Java | google-java-format |
| PHP | php-cs-fixer |
| JS/TS/React | prettier |
| CSS/HTML/JSON/YAML/MD | prettier |
| Bash | shfmt |

## 🚀 Instalação

```bash
git clone https://github.com/seu-usuario/arch+xfce.git ~/arch+xfce
cd ~/arch+xfce
chmod +x install.sh
./install.sh
```

O script vai:
1. Instalar pacotes essenciais via **pacman**
2. Instalar pacotes AUR (xss-lock) via **paru** (instala o paru se necessário)
3. Oferecer dependências opcionais (Java, PHP, Go, Rust, Nix)
4. Criar **symlinks** de `~/arch+xfce/.config/*` → `~/.config/*`

## 📁 Estrutura

```
arch+xfce/
├── .config/
│   ├── alacritty/
│   │   └── alacritty.toml
│   ├── i3/
│   │   └── config
│   ├── nvim/
│   │   ├── init.lua
│   │   ├── atalhos.txt
│   │   ├── lazy-lock.json
│   │   └── lua/
│   │       ├── dashboard.lua
│   │       └── plugins.lua
│   ├── rofi/
│   │   └── config.rasi
│   ├── gtk-3.0/
│   │   └── bookmarks
│   ├── Thunar/
│   │   ├── accels.scm
│   │   └── uca.xml
│   ├── xfce4/
│   │   ├── helpers.rc
│   │   ├── help.rc
│   │   ├── xfce4-screenshooter
│   │   └── desktop/
│   │       ├── accels.scm
│   │       └── icons.screen0.yaml
│   ├── pavucontrol.ini
│   ├── user-dirs.dirs
│   └── user-dirs.locale
├── install.sh
├── README.md
└── .gitignore
```

## 🔄 Atualizando configurações

Como os arquivos em `~/.config` são **symlinks**, qualquer mudança nos arquivos do repositório reflete imediatamente nos programas:

```bash
cd ~/arch+xfce
git add .
git commit -m "atualiza config do nvim"
git push
```

## ⚙️ Dependências opcionais

Durante a instalação você pode escolher instalar:

| Runtime | Para quê |
|---|---|
| **JDK (jdk-openjdk)** | LSP Java (jdtls) + google-java-format |
| **PHP** | php-cs-fixer |
| **Go** | gofumpt |
| **Rust (rustup)** | rustfmt + rust-analyzer |
| **Nix** | alejandra formatter |

## 🔑 API Key (Avante.nvim)

O plugin `avante.nvim` usa a API do **DeepSeek**. Defina a variável de ambiente no seu shell:

```bash
export DEEPSEEK_API_KEY="sua-chave-aqui"
```

## 📝 Notas

- Roda apenas em **Arch Linux** (ou derivados)
- O script **não** é destrutivo — faz backup de configurações existentes (`.bak`)
- Neovim faz bootstrap automático dos plugins na primeira execução
# Arch
