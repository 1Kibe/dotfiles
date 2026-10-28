# dotfiles

Configurações pessoais para **Arch Linux + XFCE + i3**, versionadas para fácil replicação em qualquer máquina.

![Prévia do desktop: Neovim com dashboard alpha, terminal Alacritty Gruvbox e painéis XFCE](assets/preview.png)

<sub>Prévia renderizada a partir das configs deste repositório (cores, fontes, dashboard e painéis).</sub>

## O que está incluído

| Ferramenta | Descrição |
|---|---|
| **i3** | Window manager (com i3status, i3lock, xss-lock) |
| **Alacritty** | Terminal emulator (tema Gruvbox + FiraCode Nerd Font) |
| **Neovim** | Editor completo com LSP, autocomplete, formatters, file-tree, git e dashboard |
| **Rofi** | Application launcher (tema gruvbox-dark) |
| **Thunar** | File manager (com ações customizadas e atalhos) |
| **XFCE4** | Desktop, painéis, temas e atalhos |
| **Pavucontrol** | Controle de áudio PulseAudio/PipeWire |
| **GTK 3.0** | Bookmarks |

### Plugins do Neovim

Gerenciados via **lazy.nvim** (bootstrap automático). Cola de atalhos em [`.config/nvim/atalhos.txt`](.config/nvim/atalhos.txt).

**Interface**
- `gruvbox.nvim` — tema Gruvbox dark (contraste hard)
- `alpha-nvim` — dashboard inicial com ASCII art
- `lualine.nvim` — statusline
- `bufferline.nvim` — abas de buffers
- `neominimap.nvim` — minimapa lateral
- `indent-blankline.nvim` — guias de indentação
- `which-key.nvim` — mostra os atalhos disponíveis

**Navegação e busca**
- `telescope.nvim` (+ `telescope-ui-select`) — busca fuzzy de arquivos/texto/buffers
- `neo-tree.nvim` — explorador de arquivos lateral
- `nvim-spectre` — buscar e substituir no projeto

**Código**
- `nvim-treesitter` — syntax highlighting
- `mason.nvim` / `mason-lspconfig.nvim` / `mason-tool-installer.nvim` — instala LSPs e formatters
- `nvim-lspconfig` — LSPs: `lua_ls`, `jdtls`, `ts_ls`, `html`, `cssls`, `eslint`
- `nvim-cmp` + `LuaSnip` — autocomplete e snippets
- `conform.nvim` — formatação de código
- `trouble.nvim` — lista de diagnósticos
- `nvim-autopairs`, `Comment.nvim`, `vim-visual-multi` — pares, comentários e múltiplos cursores

**Git e terminal**
- `gitsigns.nvim` — indicadores de git no gutter
- `vim-fugitive`, `neogit`, `diffview.nvim` — fluxo de git dentro do editor
- `toggleterm.nvim` — terminais flutuantes/integrados

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

## Instalação

```bash
git clone https://github.com/1Kibe/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

O script vai:
1. Instalar pacotes essenciais via **pacman**
2. Instalar pacotes AUR (xss-lock) via **paru** (instala o paru se necessário)
3. Perguntar se deve ativar o servidor SSH (`sshd`) — padrão é não
4. Oferecer dependências opcionais (Java, PHP, Go, Rust, Nix)
5. Configurar o filtro git que mantém o cache do painel XFCE fora dos commits
6. Criar **symlinks** de `~/dotfiles/.config/*` → `~/.config/*`
7. Aplicar configurações do XFCE (temas, painéis, wallpaper)

## Estrutura

```
dotfiles/
├── .config/
│   ├── alacritty/alacritty.toml
│   ├── i3/config
│   ├── nvim/
│   │   ├── init.lua
│   │   ├── atalhos.txt
│   │   ├── lazy-lock.json
│   │   └── lua/
│   │       ├── dashboard.lua
│   │       └── plugins.lua
│   ├── rofi/config.rasi
│   ├── gtk-3.0/bookmarks
│   ├── Thunar/
│   │   ├── accels.scm
│   │   └── uca.xml
│   ├── xfce4/
│   │   ├── helpers.rc
│   │   ├── help.rc
│   │   ├── xfce4-screenshooter
│   │   ├── desktop/
│   │   │   ├── accels.scm
│   │   │   └── icons.screen0.yaml
│   │   └── xfconf/xfce-perchannel-xml/   [painéis, temas, atalhos, wallpaper]
│   │       ├── xfce4-panel.xml
│   │       ├── xfce4-desktop.xml
│   │       ├── xfwm4.xml
│   │       ├── xsettings.xml
│   │       ├── xfce4-keyboard-shortcuts.xml
│   │       └── ...
│   ├── pavucontrol.ini
│   ├── user-dirs.dirs
│   └── user-dirs.locale
├── assets/preview.png
├── tools/xfce-panel-clean.awk
├── wallpapers/
├── install.sh
├── LICENSE
└── README.md
```

## Atualizando configurações

Como os arquivos em `~/.config` são **symlinks**, qualquer mudança nos arquivos do repositório reflete imediatamente nos programas:

```bash
cd ~/dotfiles
git add .
git commit -m "atualiza config do nvim"
git push
```

> O XFCE grava estado de uso direto nesses arquivos (ex.: o painel guarda o nome das redes Wi-Fi do systray).
> O filtro `tools/xfce-panel-clean.awk`, configurado pelo `install.sh`, remove esse cache do `xfce4-panel.xml` antes de cada commit.
> Mesmo assim, revise o `git diff` antes de dar push.

## Backup e Restore

O script oferece comandos para gerenciar suas configurações:

### Fazer Backup
```bash
./install.sh backup
# Cria: .backups/config_YYYYMMDD_HHMMSS.tar.gz (dentro do repo, ignorado pelo git)
```

### Listar Backups Disponíveis
```bash
./install.sh list
```

### Restaurar de um Backup
```bash
./install.sh restore /caminho/para/config_20240609_205600.tar.gz
# Ou simplesmente:
./install.sh restore
# E selecione o arquivo interativamente
```

## Configurações XFCE versionadas

### Painéis
- Posição e plugins dos painéis (topo e rodapé)
- Configurações de cada widget (relógio, bateria, lista de janelas, área de trabalho)

### Temas & Aparência
- **xfce4-desktop.xml** — wallpaper e ícones da área de trabalho
- **xsettings.xml** — tema GTK (Adwaita-dark), ícones (breeze-dark) e fontes
- **xfwm4.xml** — tema e botões das janelas

### Atalhos de Teclado
- **xfce4-keyboard-shortcuts.xml** — todos os atalhos do XFCE

### Outros
- Screenshooter, Thunar, notificações e gerenciamento de energia

## Dependências opcionais

Durante a instalação você pode escolher instalar:

| Runtime | Para quê |
|---|---|
| **JDK (jdk-openjdk)** | LSP Java (jdtls) + google-java-format |
| **PHP** | php-cs-fixer |
| **Go** | gofumpt |
| **Rust (rustup)** | rustfmt + rust-analyzer |
| **Nix** | alejandra formatter |

## Próximos passos

- [ ] Hyprland + Quickshell personalizado
- [ ] Suporte a Fedora e Ubuntu (lista de pacotes por distro)
- [ ] Organizar em pastas por ambiente (`common/`, `xfce/`, `hyprland/`) com GNU Stow

## Notas

- Roda apenas em **Arch Linux** (ou derivados), por enquanto
- O script **não** é destrutivo — faz backup de configurações existentes (`.bak`) antes de criar os symlinks
- Neovim faz bootstrap automático dos plugins na primeira execução
- Symlinks permitem manter configs no git com efeito imediato no sistema

## Licença

MIT — veja [LICENSE](LICENSE).
