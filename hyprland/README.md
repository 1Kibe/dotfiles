# hyprland

Configuração do **Hyprland** (em Lua) e, aos poucos, de um **Quickshell** próprio, no tema Gruvbox.

| Pasta no repo | Vira, depois do `stow` |
|---|---|
| `hyprland/.config/hypr/` | `~/.config/hypr/` |
| `hyprland/.config/quickshell/` | `~/.config/quickshell/` |
| `hyprland/.local/bin/` | `~/.local/bin/` (`hypr-atalhos`, `hypr-print`) |

Este README fica fora dos links: o GNU Stow ignora `README.*` na raiz de cada pacote.

## Como a config está organizada

| Arquivo | O que faz |
|---|---|
| `hyprland.lua` | Carrega os módulos e, por último, o `local.lua` |
| `modules/colors.lua` | Paleta Gruvbox e a cor de destaque do Windows (borda da janela ativa) |
| `modules/env.lua` | Variáveis de ambiente: cursor, Qt/Electron no Wayland, `~/.local/bin` no PATH |
| `modules/look.lua` | Bordas, espaços, cantos, sombra, blur e animações |
| `modules/input.lua` | Teclado ABNT2 e touchpad |
| `modules/actions.lua` | Nome da ação → comando (o único lugar que muda quando um módulo do Quickshell fica pronto) |
| `modules/keybinds.lua` | Tecla ou gesto → ação, sempre com descrição |
| `modules/rules.lua` | Janelas que flutuam |
| `modules/autostart.lua` | Polkit, histórico do clipboard, tema GTK e o Quickshell |
| `local.lua.example` | Modelo dos ajustes da máquina (VM e notebook) |

## Entrar no Hyprland

Na tela de login, escolha **Hyprland (uwsm-managed)**. A entrada **Hyprland** (sem uwsm) não lê `~/.config/uwsm/env` e,
ao sair, pode deixar a sessão gráfica presa no systemd; se o login voltar para a tela inicial com
"A compositor or graphical-session* target is already active", rode
`systemctl --user stop graphical-session.target graphical-session-pre.target hyprland-session.target` e entre de novo.

## Ajustes da máquina

O `local.lua` fica fora do git e é carregado por último, então pode mudar qualquer coisa (monitor, escala, cursor da VM):

    cp ~/.config/hypr/local.lua.example ~/.config/hypr/local.lua

Deixe só o bloco da máquina em que você está.

## Atalhos e gestos

`Super+F1` mostra esta lista ao vivo, lida do Hyprland em execução. As tabelas abaixo são geradas com
`hypr-atalhos --readme ~/dotfiles/hyprland/README.md` (rode de novo sempre que mudar o `keybinds.lua`).

<!-- atalhos:inicio -->

### Sistema

| Atalho | Ação |
|---|---|
| `Super (soltar) / Super+D / Super+R` | Abrir o launcher |
| `Super+Espaço / Super+Enter` | Abrir o terminal |
| `Super+E` | Abrir o Thunar |
| `Super+L` | Travar a tela |
| `Super+V` | Histórico do clipboard |
| `Super+N` | Central de notificações |
| `Super+A` | Central de controle |
| `Super+X / Ctrl+Alt+Del` | Menu de energia |
| `Super+Tab` | Visão geral das janelas |
| `Super+F1` | Lista de atalhos |
| `Ctrl+Shift+Esc` | Gerenciador de tarefas |
| `Print` | Print da tela inteira |
| `Shift+Print / Super+Shift+S` | Print de uma área |
| `Alt+Print` | Print da janela ativa |
| `Super+Shift+R` | Recarregar a config do Hyprland |
| `Super+Shift+Esc` | Sair da sessão (emergência, sem confirmação) |

### Janelas

| Atalho | Ação |
|---|---|
| `Alt+F4 / Super+Q` | Fechar |
| `Super+←` | Trocar de lugar com a da esquerda |
| `Super+→` | Trocar de lugar com a da direita |
| `Super+↑` | Maximizar |
| `Super+↓` | Restaurar |
| `Super+F` | Flutuar / voltar ao mosaico |
| `Super+Shift+F` | Tela cheia |
| `Super+J` | Alternar divisão horizontal/vertical |
| `Alt+Tab` | Próxima janela |
| `Alt+Shift+Tab` | Janela anterior |
| `Super+Alt+←` | Foco para a esquerda |
| `Super+Alt+→` | Foco para a direita |
| `Super+Alt+↑` | Foco para cima |
| `Super+Alt+↓` | Foco para baixo |
| `Super+Shift+←` | Mandar para o monitor da esquerda |
| `Super+Shift+→` | Mandar para o monitor da direita |
| `Super+botão esquerdo` | Mover com o mouse |
| `Super+botão direito` | Redimensionar com o mouse |

### Áreas

| Atalho | Ação |
|---|---|
| `Super+1..9` | Ir para a área (1 a 9) |
| `Super+Shift+1..9` | Mandar a janela para a área (1 a 9) |
| `Super+Ctrl+← / Super+roda ↑` | Área anterior |
| `Super+Ctrl+→ / Super+roda ↓` | Próxima área |
| `Super+Ctrl+D` | Nova área vazia |

### Mídia

| Atalho | Ação |
|---|---|
| `Volume +` | Aumentar o volume |
| `Volume −` | Diminuir o volume |
| `Mudo` | Mudo |
| `Microfone mudo` | Microfone mudo |
| `Brilho +` | Aumentar o brilho |
| `Brilho −` | Diminuir o brilho |
| `Play / Pause` | Tocar / pausar |
| `Próxima` | Próxima música |
| `Anterior` | Música anterior |

### Gestos do touchpad

| Gesto | Ação |
|---|---|
| 3 dedos ←/→ | Janela anterior / próxima |
| 3 dedos ↑ | Visão geral das janelas |
| 3 dedos ↓ | Mostrar a área de trabalho (área vazia) |
| 4 dedos ←/→ | Trocar de área de trabalho |
| 4 dedos ↑ / ↓ | Próxima / anterior música |
| 4 dedos (pinça) | Tocar / pausar música |

<!-- atalhos:fim -->

No Linux não existe toque de 4 dedos (o tocar/pausar foi para a pinça de 4 dedos), e o toque de 3 dedos é o clique do meio.

## Shell (Quickshell)

Cada parte do shell é um módulo do Quickshell em `.config/quickshell/`. Os atalhos chamam `qs ipc call <alvo> <função>`;
um módulo fica ligado ao atalho quando expõe o alvo abaixo (`IpcHandler`). Antes do módulo existir, o atalho não faz nada.

| Alvo | Função | Atalho |
|---|---|---|
| `launcher` | `toggle` | `Super`, `Super+D`, `Super+R` |
| `clipboard` | `toggle` | `Super+V` |
| `notifications` | `toggle` | `Super+N` |
| `controlcenter` | `toggle` | `Super+A` |
| `powermenu` | `toggle` | `Super+X`, `Ctrl+Alt+Del` |
| `overview` | `toggle` | `Super+Tab`, 3 dedos ↑ |
| `lock` | `lock` | `Super+L` |
| `taskmanager` | `toggle` | `Ctrl+Shift+Esc` (hoje abre o `btop`) |
| `cheatsheet` | `toggle` | `Super+F1` (hoje abre o `hypr-atalhos`) |

O OSD de volume e brilho não precisa de alvo: o módulo lê o PipeWire e o brilho direto.
