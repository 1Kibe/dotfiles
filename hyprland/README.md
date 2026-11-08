# hyprland

Configuração do **Hyprland** (em Lua) e do shell próprio em **Quickshell** (por enquanto a barra e os painéis dela), no tema
Gruvbox.

| Pasta no repo | Vira, depois do `stow` |
|---|---|
| `hyprland/.config/hypr/` | `~/.config/hypr/` |
| `hyprland/.config/quickshell/` | `~/.config/quickshell/` |
| `hyprland/.local/bin/` | `~/.local/bin/` (`hypr-atalhos`, `hypr-print` e `hypr-energia`, o menu de energia no terminal, reserva se o Quickshell cair) |

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

E o Quickshell, em `.config/quickshell/`:

| Arquivo | O que faz |
|---|---|
| `shell.qml` | Uma barra por monitor e os alvos de IPC dos atalhos |
| `theme/Theme.qml` | Cores, tamanhos, animações e limiares de carga: nenhum componente tem cor própria |
| `state/ShellState.qml` | Qual painel está aberto e em que monitor (um por vez) |
| `state/MediaState.qml` | Player escolhido, música, capa (baixada para o cache) e a cor dela |
| `state/SystemStats.qml` | CPU, memória, temperatura e a lista de processos, lidos do `/proc` e do `/sys` |
| `bar/` | A barra (`Bar.qml`), os itens dela e os painéis que descem (`*Panel.qml`, base em `DropPanel.qml`) |

## Entrar no Hyprland

Na tela de login, escolha **Hyprland (uwsm-managed)**. A entrada **Hyprland** (sem uwsm) não lê `~/.config/uwsm/env` e,
ao sair, pode deixar a sessão gráfica presa no systemd; se o login voltar para a tela inicial com
"A compositor or graphical-session* target is already active", rode
`systemctl --user stop graphical-session.target graphical-session-pre.target hyprland-session.target` e entre de novo.

## Ajustes da máquina

O `local.lua` fica fora do git e é carregado por último, então pode mudar qualquer coisa (monitor, escala, cursor da VM):

    cp ~/.config/hypr/local.lua.example ~/.config/hypr/local.lua

Deixe só o bloco da máquina em que você está.

**Na VM** (VMware), o bloco da VM no `local.lua` faz os apps desenharem pela CPU (`LIBGL_ALWAYS_SOFTWARE`). Os apps X11
(Spotify, jogos) precisam também desta linha em `~/.config/uwsm/env`, porque o XWayland sobe com a sessão:

    export XWAYLAND_NO_GLAMOR=1

A VM não tem sensor de temperatura da CPU, então o anel de temperatura da barra não aparece nela.

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
| `Ctrl+Shift+Esc` | Monitor do sistema (processos) |
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

O Quickshell sobe com a sessão (`autostart.lua`) e desenha uma barra em cada monitor. Ao salvar um `.qml` ele recarrega
sozinho; os erros aparecem em `qs log`.

### Barra

Uma faixa translúcida colada no topo (o Hyprland desfoca o que está atrás), com os cantos de baixo arredondados:

| Parte | Mostra | Mouse |
|---|---|---|
| Esquerda | Áreas de trabalho como pontinhos (1 a 5 sempre, as outras quando têm janela; a ativa é um traço) | Clique vai para a área; a roda passa para a anterior/próxima |
| Esquerda | Anéis de CPU, memória e temperatura da CPU, com o número ao lado; amarelo acima de 70% (75 °C) e vermelho acima de 90% (90 °C). Sem sensor, o de temperatura some | Passar o mouse mostra o resumo; clique abre o painel do sistema |
| Centro | Dia e hora (`qua 07/11  16:42`). Com música tocando vira uma ilha com a capa desfocada ao fundo, a capinha e um equalizador | Passar o mouse mostra a data (ou a música); clique abre o painel de música; clique do meio toca/pausa |
| Direita | Volume, rede, Bluetooth, bateria (Bluetooth e bateria somem se a máquina não tem) e o botão de energia | Roda no volume muda 5%; clique em cada um abre o painel dele |

### Painéis

Descem da barra, um por vez. Esc ou um clique fora fecham. Os atalhos abrem o mesmo painel no monitor em foco.

| Painel | O que tem |
|---|---|
| Rede | Wi-Fi liga/desliga, estado do cabo e as redes por sinal. Clique conecta; rede nova pede a senha ali mesmo (a senha vai direto para o NetworkManager). "Mais opções…" abre o `nm-connection-editor` |
| Volume | Saída e microfone: mudo, volume e a lista de dispositivos (clique escolhe o padrão) |
| Bluetooth | Liga/desliga e um cartão por aparelho (conectados, pareados e "Por perto", achados com "Procurar"). "Mais opções…" abre o `bluetui` |
| Música | Capa desfocada ao fundo, música, artista e álbum, progresso (clique pula), anterior/tocar/próxima e "Ir para o player". Com mais de um player, botões no topo escolhem qual a barra controla |
| Energia | Sair, Suspender, Reiniciar e Desligar. Reiniciar e Desligar pedem um segundo clique |
| Sistema | Anéis grandes de CPU, memória e temperatura, tempo ligado e os 8 processos que mais gastam CPU ou memória (CPU do momento, atualizado a cada 2 s). O ✕ de um processo seu pede um segundo clique e encerra ele; os da sessão (Hyprland, Xwayland, PipeWire, o próprio Quickshell) não têm ✕. "Abrir o btop" no rodapé |

### Atalhos do shell

Os atalhos chamam `qs ipc call <alvo> <função>`; um módulo fica ligado ao atalho quando expõe o alvo abaixo (`IpcHandler`).
Antes do módulo existir, o atalho não faz nada ou usa o substituto indicado.

| Alvo | Função | Atalho |
|---|---|---|
| `launcher` | `toggle` | `Super`, `Super+D`, `Super+R` (hoje abre o rofi) |
| `clipboard` | `toggle` | `Super+V` (hoje: histórico do cliphist no rofi) |
| `notifications` | `toggle` | `Super+N` |
| `controlcenter` | `toggle` | `Super+A` |
| `powermenu` | `toggle` | `Super+X`, `Ctrl+Alt+Del` (painel de energia da barra) |
| `overview` | `toggle` | `Super+Tab`, 3 dedos ↑ |
| `lock` | `lock` | `Super+L` |
| `taskmanager` | `toggle` | `Ctrl+Shift+Esc` (painel do sistema da barra) |
| `cheatsheet` | `toggle` | `Super+F1` (hoje abre o `hypr-atalhos`) |

Outros alvos, para scripts:

| Comando | O que faz |
|---|---|
| `qs ipc call panel toggle <nome>` | Abre ou fecha um painel no monitor em foco: `power`, `network`, `volume`, `bluetooth`, `media`, `system` |
| `qs ipc call taskmanager stats` | Os números do painel do sistema em JSON |

O OSD de volume e brilho não precisa de alvo: o módulo lê o PipeWire e o brilho direto.

### Spotify

O Spotify é o cliente oficial do `spotify-launcher`, aberto pelo `spotify-abrir` (é o que a entrada do menu chama). Antes de
abrir, ele instala ou atualiza o cliente e, se a versão mudou, aplica de novo o Spicetify com o Marketplace (a atualização
apaga os dois). O Spotify roda pelo XWayland e aparece na ilha da barra pelo MPRIS.

Extensões, tema (Hazy) e snippets ficam no próprio Spotify, em `~/.cache/spotify`; limpar esse cache apaga tudo. Para
trazer de volta: no Spotify, carrinho → engrenagem → Back up/Restore → **Import from file**, escolhendo
`spicetify/marketplace-backup.json` do repo, e feche com `Ctrl+Q` para gravar.

### Problemas conhecidos

- Um alvo de IPC novo (`IpcHandler`) só aparece reiniciando o Quickshell. Pelo Hyprland, para ele herdar o ambiente da
  sessão: `qs kill; hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`. Se a barra cair, `Super+X` não abre nada: use `hypr-energia`
  num terminal.
- Um adaptador Bluetooth ligado depois do login só aparece na barra depois de reiniciar o Quickshell.
- Na VM, o Spotify gasta perto de um núcleo inteiro só para desenhar a tela (não há GPU; `--disable-gpu` não muda nada).
  Feche com `Ctrl+Q` quando não estiver ouvindo: fechar a janela deixa ele na bandeja.
- O `wl-copy` não chega aos apps do XWayland (o Spotify, por exemplo); para eles, use `xclip -selection clipboard` (vem
  com o ambiente `xfce`) ou, no Spotify, o "Import from file".
- Apps X11 só usam o cursor Bibata por causa do `~/.local/share/icons/default/index.theme` (pacote `common`).
