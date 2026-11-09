# hyprland

Configuração do **Hyprland** (em Lua) e do shell próprio em **Quickshell** (por enquanto a barra, os painéis, o clipboard e a
captura de tela), no tema Gruvbox, e do visualizador de imagens **swayimg**.

| Pasta no repo | Vira, depois do `stow` |
|---|---|
| `hyprland/.config/hypr/` | `~/.config/hypr/` |
| `hyprland/.config/quickshell/` | `~/.config/quickshell/` |
| `hyprland/.config/swayimg/` | `~/.config/swayimg/` |
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
| `state/ClipboardStore.qml` | Histórico do cliphist, tipos, prévias de imagem, fixados, copiar, apagar e limpar |
| `state/NotesStore.qml` | Notas rápidas (post-its) |
| `state/EmojiStore.qml` | Lista de emoji do Unicode e os recentes |
| `bar/` | A barra (`Bar.qml`), os itens dela e os painéis que descem (`*Panel.qml`, base em `DropPanel.qml`) |
| `clipboard/` | O clipboard do `Super+V`: tela escura, faixa com os cartões, notas e emoji |

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
| `Super+Shift+XF86Assistant` | Abrir o lançador (tecla Copilot) |
| `Super+Espaço / Super+Enter` | Abrir o terminal |
| `Super+E` | Abrir o Thunar |
| `Super+L` | Travar a tela |
| `Super+V` | Histórico do clipboard |
| `Super+N` | Central de notificações |
| `Super+A` | Central de controle |
| `Super+I` | Central de controle (tecla engrenagem) |
| `Super+X / Ctrl+Alt+Del` | Menu de energia |
| `Super+Tab` | Visão geral das janelas |
| `Super+F1` | Lista de atalhos |
| `Ctrl+Shift+Esc` | Monitor do sistema (processos) |
| `Print` | Captura de tela (área, janela ou tela, com anotação) |
| `Shift+Print` | Print da tela inteira |
| `Super+Shift+S` | Print de uma área |
| `Alt+Print` | Print da janela ativa |
| `Super+Shift+T` | Copiar o texto de uma área (OCR) |
| `Super+Alt+R` | Gravar a tela / parar a gravação |
| `XF86Calculator` | Calculadora |
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

### Clipboard (Super+V)

`Super+V` escurece a tela e sobe uma faixa de baixo com os 100 itens mais recentes do histórico (o `cliphist` grava tudo o
que é copiado; senhas marcadas como sensíveis pelo gerenciador de senhas não entram). Escolher um item **só copia**: depois
é colar onde quiser.

- **Cartões:** o tipo no topo; texto até 5 linhas com "…"; link em azul; código em verde; cor com a amostra; imagem com a
  prévia (o tamanho no topo). Os chips filtram por tipo e digitar já busca.
- **Fixados:** ficam no começo, com borda amarela, e sobrevivem ao "Limpar". O pino no canto (ou `Ctrl+P`) fixa e desafixa.
- **Limpar:** apaga o histórico inteiro, com um segundo clique para confirmar. Os fixados ficam.
- **Notas:** post-its acima da faixa, numa grade de 6 por linha que rola para baixo. "+ Nova nota" cria uma; título e texto
  se editam no lugar e salvam sozinhos; os botões trocam a cor (5 cores), copiam o texto e apagam (com segundo clique).
  Arraste pela alça do topo para mudar a ordem.
- **Emoji:** a aba Emoji (ou `Tab`) mostra os emoji por grupo, com os recentes; a busca é pelo nome em inglês ("heart",
  "cat"). Clicar copia.

| Tecla | Faz |
|---|---|
| `←` `→` (e `↑` `↓` nos emoji) | Andam pelos cartões |
| `Enter` | Copia e fecha |
| `Ctrl+P` | Fixa ou desafixa |
| `Del` | Apaga do histórico |
| `Tab` | Troca entre Histórico e Emoji |
| Digitar | Busca |
| `Esc` | Limpa a busca; de novo, fecha (dentro de uma nota, volta para a busca) |

Clicar na área escura ou `Super+V` de novo também fecha.

Onde ficam os dados (fora do repo, só nesta máquina; pasta `700`, arquivos `600`):

| O quê | Onde |
|---|---|
| Histórico | `~/.cache/cliphist/db` (do `cliphist`) |
| Fixados | `~/.local/share/quickshell/clipboard/pins.json` e as imagens fixadas na mesma pasta |
| Notas | `~/.local/share/quickshell/clipboard/notes.json` |
| Emoji recentes | `~/.local/share/quickshell/clipboard/emoji-recent.json` |
| Prévias de imagem | `$XDG_RUNTIME_DIR/quickshell-clip` (memória; apagadas ao fechar) |

**Atenção:** apagar `~/.local/share/quickshell` apaga os fixados e as notas. Um arquivo que não dá para ler vira `.bak` e o
clipboard começa vazio, sem perder o original.

### Captura de tela (Print)

| Tecla | Faz |
|---|---|
| `Print` | Abre a barra de captura no topo: **Área / Janela / Tela**, **Foto / Vídeo**, som do sistema e microfone (em Vídeo), **atraso** (0, 3, 5 ou 10 s), **OCR** e fechar. A tela congela por baixo |
| `Super+Shift+S` | Print rápido de uma área |
| `Alt+Print` | Print rápido da janela ativa |
| `Shift+Print` | Print rápido da tela inteira |
| `Super+Shift+T` | OCR: o texto de uma área vai para o clipboard |
| `Super+Alt+R` | Grava o monitor em foco (com o último som escolhido, sem atraso); de novo, para |

- **Foto:** depois de escolher a área, a barra de anotação aparece junto da seleção: seta (`A`), retângulo (`R`; com Shift,
  cheio), linha (`L`), caneta (`P`), marca-texto (`H`), texto (`T`), números (`N`) e mosaico (`M`; clique de novo no ícone
  para borrar). Tem 5 cores, 4 espessuras, desfazer e refazer.
- **Print rápido:** salva, copia e mostra um cartão no canto de baixo por 5 s (para com o mouse em cima). O lápis (ou clique
  na miniatura) abre o print na barra de anotação, e salvar **substitui o mesmo arquivo**. A pasta abre `Capturas`; a lixeira
  manda para a lixeira (a cópia no clipboard fica).
- **OCR:** em português e inglês (`tesseract`). O aviso diz quantas linhas foram copiadas, ou "Nenhum texto encontrado".
- **Vídeo:** grava a área, a janela (onde ela estava no começo) ou o monitor, com o som do sistema, o microfone, os dois
  misturados numa faixa ou nenhum. O **microfone começa desligado**; ligado, a pílula mostra o ícone dele. Enquanto grava,
  uma pílula vermelha com o tempo fica na barra, antes do volume: clique nela, em `Super+Alt+R` ou em Parar para terminar.
  O aviso "Vídeo salvo" tem o play (abre no mpv) e a pasta.
- **Atraso:** a barra some, a contagem roda e só depois a tela congela (dá para pegar um menu aberto). `Esc` cancela.

Dentro da captura:

| Tecla | Faz |
|---|---|
| `Enter` / `Ctrl+C` | Copia e salva (em Vídeo, `Enter` começa a gravar) |
| `Ctrl+S` | Só salva |
| `Ctrl+Z` / `Ctrl+Shift+Z` | Desfaz / refaz |
| Letra da ferramenta | Troca de ferramenta (lista acima) |
| `Esc` | Sai sem salvar |

| O quê | Onde |
|---|---|
| Fotos | `~/Imagens/Capturas/AAAA-MM-DD_HH-MM-SS.png` (a pasta Imagens do `xdg-user-dir`), na resolução real da tela |
| Vídeos | `~/Vídeos/Capturas/AAAA-MM-DD_HH-MM-SS.mp4` |
| Últimas escolhas (modo, foto/vídeo, atraso, som, cor, espessura) | `~/.local/state/quickshell/capture.json` |
| Tela congelada, recortes do OCR e do editor | Memória e `$XDG_RUNTIME_DIR/quickshell-capture` (apagados ao fechar) |

### Atalhos do shell

Os atalhos chamam `qs ipc call <alvo> <função>`; um módulo fica ligado ao atalho quando expõe o alvo abaixo (`IpcHandler`).
Antes do módulo existir, o atalho não faz nada ou usa o substituto indicado.

| Alvo | Função | Atalho |
|---|---|---|
| `launcher` | `toggle` | `Super`, `Super+D`, `Super+R` (hoje abre o rofi) |
| `clipboard` | `toggle` | `Super+V` (clipboard do Quickshell) |
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
| `qs ipc call clipboard stats` | Contagens do clipboard em JSON (itens por tipo, fixados, tempo de leitura); nunca o conteúdo |
| `qs ipc call capture open` / `ocr` / `record` | O mesmo que `Print`, `Super+Shift+T` e `Super+Alt+R` |
| `qs ipc call capture card <arquivo>` | Mostra o cartão de um print (só PNG da pasta `Capturas`; o `hypr-print` chama no fim) |
| `qs ipc call capture stats` | O estado da captura em JSON (aberta, modo, gravando, tempo); nunca caminhos ou conteúdo |

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
- Na VM a gravação sai **preta**: o gravador não acha uma placa de vídeo de verdade. O arquivo, o tempo e o som saem certos.
- Na VM (VMware com o teclado preso), a `PrtSc` chega como `Super+Shift+S` e `Fn+PrtSc` como `Print`; `Shift+PrtSc` não
  chega.

## Visualizadores (imagem e vídeo)

O `install.sh` deixa o **swayimg** como padrão para imagens e o **mpv** para vídeos (`xdg-mime`, no
`~/.config/mimeapps.list`). Os dois usam as cores e a fonte do shell.

**swayimg** (imagens, `~/.config/swayimg/init.lua`). Abrir uma imagem lista as outras da mesma pasta.

| Tecla | Faz |
|---|---|
| `←` `→` / roda com Shift | Imagem anterior / próxima |
| `Enter` / `G` | Troca entre a imagem e a galeria de miniaturas (na galeria, clique abre) |
| `I` | Painel de informações (arquivo, formato, tamanho, data, câmera) |
| `+` `−` / roda | Zoom (a roda aproxima onde está o mouse); `0` volta ao normal. Na galeria, `+` `−` e `Ctrl`+roda mudam o tamanho das miniaturas |
| `R` / `Shift+R` | Gira |
| `F` / `F11` | Tela cheia |
| `S` | Apresentação (5 s por imagem) |
| `Delete` | Manda para a lixeira: aperte de novo em até 3 s para confirmar. Nunca apaga de vez |
| `Esc` / `Q` | Fecha |

**mpv** (vídeos, `~/.config/mpv`, com a interface **uosc**). Os controles aparecem com o mouse perto da borda de baixo;
o botão direito abre o menu (legendas, faixas de áudio, capítulos) e `Tab` mostra os controles por um instante. As
outras teclas são as do mpv (`Espaço` pausa, `←` `→` voltam e avançam 5 s, `F` tela cheia, `Q` fecha). No fim, o vídeo
fica parado na tela em vez de fechar.

- O swayimg só funciona no Wayland: na sessão XFCE as imagens não abrem por ele (ele também é o único visualizador
  instalado lá).
- Na VM o mpv desenha pelo processador (`gpu-sw=yes` no `mpv.conf`), porque não há placa de vídeo.
