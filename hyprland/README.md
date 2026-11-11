# hyprland

Configuração do **Hyprland** (em Lua) e do shell próprio em **Quickshell** (por enquanto a barra, os painéis, o clipboard, a
captura de tela, o bloqueio de tela e a tela de login), no tema Gruvbox, e do visualizador de imagens **swayimg**.

| Pasta no repo | Vira, depois do `stow` |
|---|---|
| `hyprland/.config/hypr/` | `~/.config/hypr/` |
| `hyprland/.config/quickshell/` | `~/.config/quickshell/` |
| `hyprland/.config/swayimg/` | `~/.config/swayimg/` |
| `hyprland/.local/bin/` | `~/.local/bin/` (`hypr-atalhos`, `hypr-print`, `hypr-calculadora`, `hypr-travar`, `hypr-energia-ociosa` e `hypr-energia`, o menu de energia no terminal, reserva se o Quickshell cair) |

Este README fica fora dos links: o GNU Stow ignora `README.*` na raiz de cada pacote.

## Como a config está organizada

| Arquivo | O que faz |
|---|---|
| `hyprland.lua` | Carrega os módulos, o `settings.lua` e, por último, o `local.lua` |
| `modules/colors.lua` | Paleta Gruvbox e a cor de destaque do Windows (borda da janela ativa) |
| `modules/env.lua` | Variáveis de ambiente: cursor, Qt/Electron no Wayland, `~/.local/bin` no PATH |
| `modules/look.lua` | Bordas, espaços, cantos, sombra, blur e animações |
| `modules/input.lua` | Teclado ABNT2 e touchpad |
| `modules/actions.lua` | Nome da ação → comando (o único lugar que muda quando um módulo do Quickshell fica pronto) |
| `modules/keybinds.lua` | Tecla ou gesto → ação, sempre com descrição |
| `modules/rules.lua` | Janelas que flutuam |
| `modules/autostart.lua` | Polkit, histórico do clipboard, tema GTK e o Quickshell |
| `settings.lua` | Gerado pelas Configurações (Aparência): borda da janela ativa, cantos, desfoque e cursor. Fora do git |
| `local.lua.example` | Modelo dos ajustes da máquina (VM e notebook) |
| `hypridle.conf` | Tempos de inatividade: escurecer, travar, apagar a tela e suspender (veja [Bloqueio e login](#bloqueio-e-login)) |
| `hyprlock.conf` | O bloqueio reserva, usado só quando o Quickshell não responde |

E o Quickshell, em `.config/quickshell/`:

| Arquivo | O que faz |
|---|---|
| `shell.qml` | Uma barra por monitor e os alvos de IPC dos atalhos |
| `theme/Theme.qml` | Cores, tamanhos, animações e limiares de carga: nenhum componente tem cor própria |
| `theme/corners.js` | Os cantos contínuos (a curva entra aos poucos, sem o degrau do quarto de círculo), usados pela barra e pelos painéis |
| `state/ShellState.qml` | Qual painel está aberto e em que monitor (um por vez) |
| `state/MediaState.qml` | Player escolhido, música, capa (baixada para o cache) e a cor dela |
| `state/SystemStats.qml` | CPU, memória, temperatura e a lista de processos, lidos do `/proc` e do `/sys` |
| `state/ClipboardStore.qml` | Histórico do cliphist, tipos, prévias de imagem, fixados, copiar, apagar e limpar |
| `state/NotesStore.qml` | Notas rápidas (post-its) |
| `state/EmojiStore.qml` | Lista de emoji do Unicode e os recentes |
| `state/LockState.qml` | O bloqueio: pedido de trava, senha pelo PAM, muitas tentativas, Caps Lock e o escurecer antes de travar |
| `state/BackgroundStore.qml` | O fundo do bloqueio e do login: as imagens, a checagem e o PNG final (ffmpeg) |
| `bar/` | A barra e os painéis que descem dela, numa janela só por monitor (`Bar.qml`; `BarZone.qml` reserva o espaço da barra), os itens dela e os painéis (`*Panel.qml`, base em `AttachedPanel.qml`, desenho em `AttachedShape.qml`) |
| `clipboard/` | O clipboard do `Super+V`: tela escura, faixa com os cartões, notas e emoji |
| `lock/` | A tela de bloqueio, o escolhedor de fundo, o aviso antes de travar e as peças que a tela de login também usa |
| `wallpaper/` | O papel de parede da sessão, atrás de todas as janelas |

## Entrar no Hyprland

Na tela de login, escolha **Hyprland (uwsm-managed)**. A entrada **Hyprland** (sem uwsm) não lê `~/.config/uwsm/env` e,
ao sair, pode deixar a sessão gráfica presa no systemd; se o login voltar para a tela inicial com
"A compositor or graphical-session* target is already active", rode
`systemctl --user stop graphical-session.target graphical-session-pre.target hyprland-session.target` e entre de novo.

## Ajustes da máquina

O `local.lua` fica fora do git e é carregado por último, então pode mudar qualquer coisa (monitor, escala, cursor da VM):

    cp ~/.config/hypr/local.lua.example ~/.config/hypr/local.lua

Deixe só o bloco da máquina em que você está.

O que você escolhe em Configurações → Aparência (`Super+S`) vai para o `settings.lua`, gerado pelo Quickshell e fora do git;
ele é carregado antes do `local.lua`, então a máquina continua mandando. Os papéis de parede importados pela galeria ficam em
`~/.local/share/dotfiles/wallpapers`, fora do repo.

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
| `Fechar a tampa` | Travar ao fechar a tampa |
| `Super+V` | Histórico do clipboard |
| `Super+N` | Central de notificações |
| `Super+A` | Central de controle |
| `Super+I` | Central de controle (tecla engrenagem) |
| `Super+X / Ctrl+Alt+Del` | Menu de energia |
| `Super+S` | Configurações |
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

Descem da barra, um por vez, colados nela: barra e painel são uma forma só, com cantos contínuos que crescem enquanto o painel
abre. O de energia continua a ponta direita da barra. Esc ou um clique fora fecham, sempre com a animação. Os atalhos abrem o
mesmo painel no monitor em foco.

| Painel | O que tem |
|---|---|
| Rede | Wi-Fi liga/desliga, estado do cabo e as redes por sinal. Clique conecta; rede nova pede a senha ali mesmo (a senha vai direto para o NetworkManager). "Mais opções…" abre o `nm-connection-editor` |
| Volume | Saída e microfone: mudo, volume e a lista de dispositivos (clique escolhe o padrão) |
| Bluetooth | Liga/desliga e um cartão por aparelho (conectados, pareados e "Por perto", achados com "Procurar"). "Mais opções…" abre o `bluetui` |
| Música | Capa desfocada ao fundo, música, artista e álbum, progresso (clique pula), anterior/tocar/próxima e "Ir para o player". Com mais de um player, botões no topo escolhem qual a barra controla |
| Energia | Bloquear, Sair, Suspender, Reiniciar e Desligar. Suspender trava antes; Reiniciar e Desligar pedem um segundo clique |
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
| `Print` | Abre a barra de captura, que desce do relógio colada na barra: **Área / Janela / Tela**, **Foto / Vídeo**, som do sistema e microfone (em Vídeo), **atraso** (0, 3, 5 ou 10 s), **OCR** e fechar. A tela congela por baixo |
| `Super+Shift+S` | Print rápido de uma área |
| `Alt+Print` | Print rápido da janela ativa |
| `Shift+Print` | Print rápido da tela inteira |
| `Super+Shift+T` | OCR: o texto de uma área vai para o clipboard |
| `Super+Alt+R` | Grava o monitor em foco (com o último som escolhido, sem atraso); de novo, para |

- **Foto:** depois de escolher a área, a barra de anotação sobe da borda de baixo da tela, centralizada (fica fora do PNG):
  seta (`A`), retângulo (`R`; com Shift, cheio), linha (`L`), caneta (`P`), marca-texto (`H`), texto (`T`), números (`N`) e
  mosaico (`M`; clique de novo no ícone para borrar). Tem 5 cores, 4 espessuras, desfazer e refazer.
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
| `qs ipc call lock stats` | O estado do bloqueio em JSON (travado, conferindo, escurecido, erro); nunca a senha |
| `qs ipc call lock background` | Abre o escolhedor do fundo do bloqueio e do login (não abre com a tela travada) |
| `qs ipc call lock dim <segundos>` / `undim` | O escurecer antes de travar (o `hypridle` chama); só visual, nunca trava nem destrava |

Não existe alvo para destravar: só a senha, pelo PAM, destrava.

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
- Na VM no Windows, o `Super+L` é do Windows: ele tranca a sessão do Windows antes de chegar ao Hyprland. Na VM, trave pelo
  menu de energia (Bloquear) ou por `hyprctl dispatch 'hl.dsp.exec_cmd("hypr-travar")'`. No notebook o `Super+L` vai direto.

## Bloqueio e login

A tela de bloqueio e a tela de login são do Quickshell, com o mesmo tema, relógio, cartão do usuário e campo de senha. A
senha passa só pelo PAM: o bloqueio usa o serviço `/etc/pam.d/quickshell-lock`, o login usa o do greetd. Nada destrava
sem a senha. O serviço do bloqueio vem do `install.sh`; o do greetd vem com o pacote.

### Travar

- `Super+L`, **Bloquear** no menu de energia (`Super+X`) ou fechar a tampa. Tudo chama o `hypr-travar`, que espera o
  Hyprland confirmar que todas as telas estão cobertas. Suspender (pelos menus, pela tampa ou pelo `hypridle`) também trava
  antes.
- Na VM no Windows, o `Super+L` é do Windows (veja [Problemas conhecidos](#problemas-conhecidos)).
- No Hyprland, `allow_session_lock_restore` fica desligado (`modules/look.lua`): ligado, qualquer programa poderia
  trocar a tela de bloqueio por outra e destravar sem senha. O custo está em
  [Se a tela de bloqueio cair](#se-a-tela-de-bloqueio-cair).

### Tempos de inatividade

Ficam no `hypridle.conf` (os mesmos do plano "Equilibrado" do Windows, na tomada e na bateria):

| Parado há | Acontece |
|---|---|
| 4 min 30 s | A tela escurece, com uma contagem de 30 s até travar |
| 5 min | Trava |
| 5 min 10 s | Apaga a tela |
| 60 min | Suspende, só na bateria |

Qualquer tecla ou movimento do mouse desfaz o escurecer. Um vídeo tocando segura tudo; música não. Para mudar, edite o
`timeout` de cada `listener`; o `30` do `dim 30` é a contagem, e tem que ser a diferença entre travar e escurecer
(300 − 270). Depois, `systemctl --user restart hypridle`.

### Fundo

`qs ipc call lock background` abre o escolhedor do fundo, que vale para o bloqueio e para o login. Ele mostra três abas
(os papéis de parede do repo, a pasta Imagens e as Capturas), confere cada imagem e grava um PNG em
`/usr/local/share/dotfiles/login/fundo.png`, de onde o login copia. Não abre com a tela travada. Sem fundo, ou com um
arquivo que não passa na checagem, fica a cor do tema.

A foto do cartão do bloqueio vem de `/var/lib/AccountsService/icons/<usuário>`, se existir; sem ela fica a inicial do
nome. A tela de login nunca abre a foto (mostra sempre a inicial), porque ela roda antes de qualquer login e não lê
arquivos dos usuários.

### Senha errada muitas vezes

O PAM (`pam_faillock`, com os valores do Arch) trava a conta depois de **3 senhas erradas em 15 minutos**, por **10
minutos**. Na tela aparece "Muitas tentativas" com a contagem. Para destravar antes, como root, num console:

    sudo faillock --user <usuário> --reset

Limitações:

- No login, o aviso só aparece na tentativa **seguinte** à que travou a conta (o PAM trava na 3ª errada, mas só diz isso na
  4ª). O "Aguarde" some com a contagem ou trocando de usuário; quem decide é o PAM: conta ainda travada, o aviso volta;
  conta liberada, entra.
- No bloqueio, o limite só vale se você entrou com senha desde que o computador ligou (é o login, como root, que cria o
  registro em `/run/faillock`). Numa sessão aberta sem senha, o bloqueio não tem limite de tentativas.

### Se a tela de bloqueio cair

Se o Quickshell parar de responder, o `hypr-travar` chama o **bloqueio reserva** (`hyprlock`, com o `hyprlock.conf`), que
mostra "Bloqueio reserva" na tela e usa o serviço `/etc/pam.d/hyprlock`. Ele aceita a senha normalmente. Ele não mostra o
"Muitas tentativas", mas o limite de tentativas vale do mesmo jeito (é o mesmo `pam_faillock`). Risco aceito: com o
reserva na tela, um programa da sua sessão pode destravá-lo mandando um sinal (`SIGUSR1`); com o bloqueio do Quickshell
isso não existe.

Se o Quickshell cair **com a tela travada**, o Hyprland deixa a tela coberta com um aviso de que a tela de bloqueio parou
(é o custo do `allow_session_lock_restore` desligado). Para voltar, por SSH ou por um console de texto (`Ctrl+Alt+F2` no
notebook; na VM VMware, `Ctrl+Alt+Espaço` e depois `F2` segurando `Ctrl+Alt`):

    hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'
    hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hypr-travar")'
    exit

O primeiro comando tira a tela coberta, o segundo trava de novo de dentro da sessão (o `hypr-travar` sobe o Quickshell se
precisar; rodado direto no console ele não acha a sessão), e o `exit` fecha o console. Volte para a sessão com
`Ctrl+Alt+F1` e digite a senha. Um console de texto esquecido sai sozinho depois de 10 minutos sem comando
(`/etc/profile.d/tmout.sh`); um `bash` aberto dentro dele não tem esse limite.

Não edite os `.qml` do `~/.config/quickshell` com a tela travada: o Quickshell recarrega sozinho quando um arquivo muda, e
um erro no meio da edição derruba a tela de bloqueio.

### Tela de login

O greetd abre o `/etc/greetd/start-greeter`, que sobe o Quickshell (`/etc/greetd/quickshell`) dentro do **cage**, no
último monitor, como o usuário `greeter`. O teclado do login é o do sistema (`localectl`), então a senha sai com o mesmo
layout da sessão. Na VM, o `start-greeter` desenha pela CPU (o cage não sobe com a placa de vídeo da VMware).

**Se o login não abrir**, troque para o `agreety` (o login de texto que vem com o greetd). Por SSH ou pelo console de
texto (`Ctrl+Alt+F2` no notebook; na VM, `Ctrl+Alt+Espaço` e `F2` segurando `Ctrl+Alt`), que no notebook é o único
caminho:

    sudo cp /etc/greetd/config.toml.bak /etc/greetd/config.toml
    sudo systemctl restart greetd

O `config.toml.bak` é a config que o greetd tinha antes do `install.sh` (a do pacote usa o `agreety`). Para voltar ao
login do Quickshell:

    sudo install -m644 -o root -g root ~/dotfiles/system/greetd/config.toml /etc/greetd/config.toml
    sudo systemctl restart greetd

### O que isto protege

Contra alguém que senta na frente do computador quando você saiu: com a tela travada, só a senha entra. Sem criptografia
do disco (LUKS), quem tira o disco ou liga por um pendrive lê tudo; o bloqueio e o login não mudam isso.

### Falta conferir no notebook

- Fechar a tampa trava e suspende de verdade (na VM não existe tampa nem suspensão real).
- O nome da tampa no Hyprland (`hyprctl devices`); se não for `Lid Switch`, o `local.lua.example` mostra como trocar.
- O `Super+L` e a `PrtSc` chegando direto ao Hyprland.
- O login e o bloqueio na placa de vídeo (Intel Arc), sem o desenho pela CPU da VM.

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
