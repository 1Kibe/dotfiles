# dotfiles

Configurações pessoais para **Arch Linux + XFCE + i3**, versionadas para fácil replicação em qualquer máquina. Organizadas em pastas por ambiente e linkadas com **GNU Stow**, prontas para receber Hyprland e outras distros.

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

Gerenciados via **lazy.nvim** (bootstrap automático). Cola de atalhos em [`common/.config/nvim/atalhos.txt`](common/.config/nvim/atalhos.txt).

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
1. Detectar a distro pelo `/etc/os-release` e escolher a lista em `packages/` (`arch`, `fedora` ou `ubuntu`)
2. Perguntar quais ambientes ativar: `xfce` (padrão sim) e `hyprland` (padrão não). O `common` entra sempre
3. Instalar os pacotes das seções `[common]` + ambientes escolhidos (no Arch via **pacman**, e os `aur:` via **paru**, que é instalado se necessário)
4. Ativar NetworkManager e Bluetooth, e perguntar se deve ativar o servidor SSH (`sshd`) — padrão é não
5. Oferecer dependências opcionais (Java, PHP, Go, Rust, Nix) — só no Arch
6. Configurar o filtro git que mantém o cache do painel XFCE fora dos commits
7. Linkar as configs com `stow` (`common` + ambientes escolhidos) em `~`
8. Aplicar configurações do XFCE (temas, painéis, wallpaper), se o ambiente `xfce` foi escolhido

Os ambientes também podem ir direto na linha de comando, sem o menu:

```bash
./install.sh install xfce   # pacotes + links de common e xfce
./install.sh link xfce      # só os links, sem pacotes nem serviços
./install.sh unlink xfce    # remove os links do xfce
```

## Ambientes

Cada pasta de ambiente é um pacote do GNU Stow: ela espelha o `$HOME`, então `common/.config/nvim` vira `~/.config/nvim`.

| Pasta | Conteúdo | Quando entra |
|---|---|---|
| `common/` | Neovim, Alacritty, Rofi, wallpapers | Sempre |
| `xfce/` | XFCE, i3, Thunar, GTK 3, Pavucontrol, `user-dirs.*` | Ambiente `xfce` |
| `hyprland/` | Hyprland e Quickshell (ainda vazio) | Ambiente `hyprland`; pulado enquanto não tiver configs |

As listas de pacotes seguem a mesma divisão: cada `packages/<distro>.txt` tem as seções `[common]`, `[xfce]` e `[hyprland]`. No Arch, o prefixo `aur:` manda o pacote para o helper AUR.

## Estrutura

```
dotfiles/
├── common/.config/
│   ├── alacritty/alacritty.toml
│   ├── nvim/
│   │   ├── init.lua
│   │   ├── atalhos.txt
│   │   ├── lazy-lock.json
│   │   └── lua/
│   │       ├── dashboard.lua
│   │       └── plugins.lua
│   ├── rofi/config.rasi
│   └── wallpapers/
├── xfce/.config/
│   ├── i3/config
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
├── hyprland/
│   ├── README.md
│   └── .config/
│       ├── hypr/
│       └── quickshell/
├── packages/
│   ├── arch.txt
│   ├── fedora.txt                        [TODO]
│   └── ubuntu.txt                        [TODO]
├── assets/preview.png
├── tools/xfce-panel-clean.awk
├── install.sh
├── LICENSE
└── README.md
```

## Atualizando configurações

Como os arquivos em `~/.config` são **symlinks** criados pelo `stow`, qualquer mudança nos arquivos do repositório reflete imediatamente nos programas:

```bash
cd ~/dotfiles
git add .
git commit -m "atualiza config do nvim"
git push
```

> O XFCE grava estado de uso direto nesses arquivos (ex.: o painel guarda o nome das redes Wi-Fi do systray).
> O filtro `tools/xfce-panel-clean.awk`, configurado pelo `install.sh`, remove esse cache do `xfce4-panel.xml` antes de cada commit.
> Mesmo assim, revise o `git diff` antes de dar push.

Depois de um `git pull` que adiciona ou move arquivos, rode `./install.sh link` para atualizar os links.

## Migrando do layout antigo

Até esta versão as configs ficavam em `.config/` na raiz do repo, e o `install.sh` criava links `~/.config/<nome>` apontando para lá. Depois do `git pull` esses links ficam quebrados. Para trocar pelos links do `stow`:

```bash
cd ~/dotfiles
git pull
./install.sh link xfce
```

O `link` apaga só os links que apontam para dentro do repo e recria tudo com o `stow`. Qualquer outro arquivo no caminho vira `<nome>.bak`. Os wallpapers, que antes eram copiados para `~/.config/wallpapers`, viram `~/.config/wallpapers.bak` e podem ser apagados (o repo tem os mesmos arquivos).

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

- [x] Organizar em pastas por ambiente (`common/`, `xfce/`, `hyprland/`) com GNU Stow
- [ ] Hyprland + Quickshell personalizado em `hyprland/` (configs e seção `[hyprland]` de `packages/arch.txt`)
- [ ] Listas de pacotes para Fedora e Ubuntu (`packages/fedora.txt` e `packages/ubuntu.txt`, hoje só com as seções vazias)
- [ ] Dependências opcionais do Neovim fora do Arch

## Notas

- Feito para **Arch Linux** (e derivados). Em Fedora e Ubuntu o script já detecta a distro e cria os links, mas ainda não instala pacotes além do `stow`
- O script **não** é destrutivo — o que estiver no caminho dos links vira `.bak` em vez de ser apagado
- Neovim faz bootstrap automático dos plugins na primeira execução
- Symlinks permitem manter configs no git com efeito imediato no sistema

## Licença

MIT — veja [LICENSE](LICENSE).
