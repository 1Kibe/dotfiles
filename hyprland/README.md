# hyprland

Configuração do **Hyprland** (em Lua) e do shell próprio em **Quickshell** (por enquanto a barra, os painéis, o clipboard, a
captura de tela, o bloqueio de tela e a tela de login), no tema Gruvbox, e do visualizador de imagens **swayimg**.

| Pasta no repo | Vira, depois do `stow` |
|---|---|
| `hyprland/.config/hypr/` | `~/.config/hypr/` |
| `hyprland/.config/quickshell/` | `~/.config/quickshell/` |
| `hyprland/.config/swayimg/` | `~/.config/swayimg/` |
| `hyprland/.local/bin/` | `~/.local/bin/` (`hypr-atalhos`, `hypr-print`, `hypr-flutuar` (Super+F), `hypr-clip-imagem` (imagens no histórico do clipboard), `hypr-calculadora`, `hypr-travar`, `hypr-hypridle` (sobe o hypridle com os tempos das Configurações), `hypr-energia-ociosa` e `hypr-energia`, o menu de energia no terminal, reserva se o Quickshell cair, `hypr-atualizar` e `hypr-tailscale`, os terminais da central de controle) |

Este README fica fora dos links: o GNU Stow ignora `README.*` na raiz de cada pacote.

## Como a config está organizada

| Arquivo | O que faz |
|---|---|
| `hyprland.lua` | Carrega os módulos, o `dotfiles_settings.lua` e, por último, o `local.lua` |
| `modules/colors.lua` | Paleta Gruvbox e a cor de destaque do Windows (borda da janela ativa) |
| `modules/env.lua` | Variáveis de ambiente: cursor, Qt/Electron no Wayland, `~/.local/bin` no PATH |
| `modules/look.lua` | Bordas, espaços, cantos, sombra, blur e animações |
| `modules/input.lua` | Teclado ABNT2 e touchpad |
| `modules/actions.lua` | Nome da ação → comando (o único lugar que muda quando um módulo do Quickshell fica pronto) |
| `modules/keybinds.lua` | Tecla ou gesto → ação, sempre com descrição |
| `modules/rules.lua` | Janelas que flutuam |
| `modules/autostart.lua` | Polkit, histórico do clipboard, tema GTK e o Quickshell |
| `dotfiles_settings.lua` | Gerado pelas Configurações (Aparência): borda da janela ativa, cantos, desfoque e cursor. Fora do git |
| `local.lua.example` | Modelo dos ajustes da máquina (VM e notebook) |
| `hypridle.conf` | Travar antes de suspender e os tempos de inatividade padrão; os escolhidos em Configurações → Energia entram pelo `hypr-hypridle` (veja [Tempos de inatividade](#tempos-de-inatividade)) |
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
| `state/NotesStore.qml` | As anotações da gaveta do clipboard |
| `state/EmojiStore.qml` | Lista de emoji do Unicode e os recentes |
| `state/LockState.qml` | O bloqueio: pedido de trava, senha pelo PAM, muitas tentativas, Caps Lock e o escurecer antes de travar |
| `state/BackgroundStore.qml` | O fundo do bloqueio e do login: as imagens, a checagem e o PNG final (ffmpeg) |
| `bar/` | A barra e os painéis que descem dela, numa janela só por monitor (`Bar.qml`; `BarZone.qml` reserva o espaço da barra), os itens dela e os painéis (`*Panel.qml`, base em `AttachedPanel.qml`, desenho em `AttachedShape.qml`) |
| `clipboard/` | O clipboard do `Super+V`: a gaveta de baixo com os cartões, o emoji e as anotações |
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

O que você escolhe em Configurações → Aparência (`Super+S`) vai para o `dotfiles_settings.lua`, gerado pelo Quickshell e fora do git;
ele é carregado antes do `local.lua`, então a máquina continua mandando. Os papéis de parede importados pela galeria ficam em
`~/.local/share/dotfiles/wallpapers`, fora do repo.

**Na VM** (VMware), o bloco da VM no `local.lua` faz os apps desenharem pela CPU (`LIBGL_ALWAYS_SOFTWARE`). Os apps X11
(Spotify, jogos) precisam também desta linha em `~/.config/uwsm/env`, porque o XWayland sobe com a sessão:

    export XWAYLAND_NO_GLAMOR=1

A VM não tem sensor de temperatura da CPU, então o anel de temperatura da barra não aparece nela.

## Atalhos e gestos

`Super+F1` mostra esta lista ao vivo, lida do Hyprland em execução. As tabelas abaixo são geradas com
`hypr-atalhos --readme ~/dotfiles/hyprland/README.md` (rode de novo sempre que mudar o `keybinds.lua`).
O `hypr-atalhos --json` dá a mesma lista para a página Configurações → Atalhos.
Os gestos do touchpad na tabela são os padrões: cada um muda em Configurações → Gestos, e o `Super+F1` e a
página Atalhos mostram os escolhidos. Com a tela travada nenhum gesto roda nada (o `hypr-destravado` pergunta ao
Hyprland antes); as teclas de mídia e de volume continuam valendo travadas.

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
| `Super+X / Ctrl+Alt+Del` | Energia (central de controle) |
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
| `Super+F` | Flutuar menor e centralizada / voltar ao mosaico |
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
| 3 dedos ← | Janela anterior |
| 3 dedos → | Próxima janela |
| 3 dedos ↑ | Visão geral das janelas |
| 3 dedos ↓ | Ir para uma área vazia |
| 4 dedos ←/→ | Trocar de área de trabalho |
| 4 dedos ↑ | Próxima música |
| 4 dedos ↓ | Música anterior |
| 4 dedos (pinça) | Tocar / pausar |

<!-- atalhos:fim -->

Com várias telas, as áreas são **juntas em todas as telas** (como no Windows; Configurações → Monitores → Áreas de
trabalho): cada área tem uma parte em cada tela, `Super+N` troca todas as telas de uma vez e o foco fica onde estava,
`Super+Shift+N` manda a janela para a área N na mesma tela, e a barra mostra as mesmas áreas em todas as telas. A tela
principal (Tela 1, onde a área 1 começa) se escolhe na tela escolhida da página. Tela nova ganha o próximo lugar livre e
volta sempre com a mesma parte; tela tirada manda as janelas dela para a principal, na mesma área, e elas voltam se a
mesma tela voltar. Com uma tela só fica igual a antes. "Separadas por tela" deixa cada tela com as suas, como o Hyprland
faz sozinho.

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
| Direita | Volume, rede, Bluetooth, bateria (Bluetooth e bateria somem se a máquina não tem) e, na ponta, o símbolo do Arch, que abre a [central de controle](#central-de-controle-superi) | Roda no volume muda 5%; clique em cada um abre o painel dele |

### Painéis

Descem da barra, um por vez, colados nela: barra e painel são uma forma só, com cantos contínuos que crescem enquanto o painel
abre. A central de controle continua a ponta direita da barra. Esc ou um clique fora fecham, sempre com a animação. Os atalhos
abrem o mesmo painel no monitor em foco. Rede, volume e Bluetooth usam as mesmas listas da central.

| Painel | O que tem |
|---|---|
| Rede | A lista do Wi-Fi da central (veja [Central de controle](#central-de-controle-superi)) |
| Volume | O volume da saída em cima e o mixer da central (saídas, microfone, um nível por app) |
| Bluetooth | A lista do Bluetooth da central |
| Música | Capa desfocada ao fundo, música, artista e álbum, progresso (clique pula), anterior/tocar/próxima e "Ir para o player". Com mais de um player, botões no topo escolhem qual a barra controla |
| Sistema | Anéis grandes de CPU, memória e temperatura, tempo ligado e os 8 processos que mais gastam CPU ou memória (CPU do momento, atualizado a cada 2 s). O ✕ de um processo seu pede um segundo clique e encerra ele; os da sessão (Hyprland, Xwayland, PipeWire, o próprio Quickshell) não têm ✕. "Abrir o btop" no rodapé |

### Central de controle (Super+I)

Abre pelo símbolo do Arch na ponta direita da barra, por `Super+I` (a tecla engrenagem do notebook, F9) ou `Super+A`, no
monitor em foco. `Super+X` e `Ctrl+Alt+Del` abrem já na energia. Esc fecha a seção aberta e, de novo, a central; um clique fora
também fecha. Ela abre sempre com tudo dobrado.

De cima para baixo:

- **Topo:** a bateria (com "Conservação ligada" quando o limite de carga está ligado), a engrenagem (Configurações, como
  `Super+S`) e o botão de energia, que abre a seção da energia: Bloquear, Sair, Suspender, Reiniciar e Desligar (quais
  aparecem e quais pedem segundo clique ficam em Configurações → Energia; Reiniciar e Desligar sempre pedem).
- **Grade:** Rede, Bluetooth, Tailscale, Atualizações e Luz noturna (este só liga e desliga, com o horário embaixo). Cada botão
  com lista abre a sua seção logo abaixo, uma por vez: abrir outra fecha a que estava aberta.
- **Volume** (mudo, nível e a seta do mixer) e **brilho** (só com tela interna).
- **Em segundo plano**, no fim: os apps rodando sem janela.

Todas as seções têm o mesmo desenho: cabeçalho com o estado e o interruptor quando há, as listas em blocos, as linhas com o
valor ou a ação à direita. Cada uma fica num cartão próprio e rola por dentro quando passa da altura.

| Seção | O que tem |
|---|---|
| Rede | Liga/desliga o Wi-Fi, o cabo quando conectado e as redes: a conectada e as salvas primeiro, depois por sinal; as 5 primeiras e "Mostrar mais"; busca a partir de 9 redes. Clique conecta; rede nova pede a senha ali mesmo, e a senha vai direto ao NetworkManager. "Esquecer" pede um segundo clique. "Outra rede…" entra numa rede escondida; "Mais opções…" abre o `nm-connection-editor` |
| Bluetooth | Liga/desliga (pelo `rfkill`, como no Windows: fica desligado depois de reiniciar), os pareados com a bateria e "Por perto", achados com "Procurar aparelhos" (os sem nome ficam atrás de "+ N sem nome"). Clique conecta ou pareia (pareado aqui fica confiável); "Esquecer" pede um segundo clique. "Mais opções…" abre o `bluetui` |
| Mixer | Saídas e microfone (clique escolhe o padrão, o microfone com nível e mudo) e um nível com mudo por app tocando som |
| Atualizações | O sistema (`checkupdates`, com a hora da última verificação) e o AUR (`paru -Qua`), os 3 primeiros pacotes de cada e "e mais N". "Verificar agora" e "Atualizar tudo no terminal": abre o Kitty com o `paru -Syu`, onde se vê o que vai instalar e se digita a senha. Procura sozinho 2 min depois de entrar e a cada 6 h, nunca com a tela travada; depois do "Atualizar tudo" a lista se atualiza sozinha. O botão da grade fica amarelo com o total, e mostra só a parte conhecida ("2 do AUR") quando uma das origens não deu para ler |
| Tailscale | O estado, este aparelho (nome e endereço, com copiar), os aparelhos da tailnet (online com o endereço, offline com quando foi visto), o aviso quando a internet está saindo por outro aparelho e "Esconder nomes e endereços" (para prints; o copiar continua copiando o de verdade). O interruptor abre o terminal com `sudo tailscale up`/`down`; "Abrir o painel do Tailscale" abre o painel da conta no navegador |

**Em segundo plano.** Uma ficha por app com ícone de bandeja (o shell é a bandeja; não há ícones fixos na barra), em até duas
linhas; o resto vira "+N", que abre a lista inteira. Sem nenhum app, a faixa não aparece. Clique abre o app; o botão direito abre
o menu do próprio app; o × encerra pelo "Sair" do menu do app (só quando ele tem exatamente um; nunca força). O blueman fica sem
×, porque fechar ele derruba também o agente de pareamento do Bluetooth. Um ponto amarelo: o app pede atenção.

**O que pede senha:** a senha do Wi-Fi vai direto ao NetworkManager (nunca fica no shell); atualizar e ligar/desligar o
Tailscale abrem o terminal, onde o `sudo` pede a senha. A central nunca roda nada como root.

**Teclado:** as setas andam dentro do grupo (topo, grade, volume e brilho, a seção aberta, as fichas), Tab e Shift+Tab trocam de
grupo, Enter aperta. Aberta por atalho, o anel aparece já no primeiro botão.

**Falta conferir no notebook** (a VM não tem o hardware):

- A tecla engrenagem (F9) chegando como `Super+I`, e a bateria e a conservação com a bateria de verdade.
- Wi-Fi com as redes reais: entrar com senha, senha errada, rede escondida, "Esquecer" com o segundo clique.
- Bluetooth com rádio: ligar e desligar pelo `rfkill` (e continuar desligado depois de reiniciar), parear, conectar,
  esquecer; o blueman como ficha do segundo plano.
- O mixer com apps tocando de verdade e mais de uma saída.
- O brilho da tela interna (`brightnessctl`).
- O Tailscale logado: os aparelhos, o copiar, o aviso de saída em uso, o painel no navegador e o terminal do `sudo`.
- As atualizações com o paru compilando (na VM com 4 GB o Rust ficou sem memória; com 6 GB foi).
- O segundo plano com os apps de bandeja reais (Spotify, Steam, Discord…): os ícones, o menu de cada um e o × pelo "Sair".

### Clipboard (Super+V)

`Super+V` sobe uma gaveta da borda de baixo da tela, de um lado ao outro (com a barra embaixo, ela fica em cima da barra),
sem escurecer o resto. Ela tem três abas, todas com a mesma altura: **Clipboard**, **Emoji** e **Anotações**. A aba Clipboard
mostra os 100 itens mais recentes do histórico (o `cliphist` grava tudo o que é copiado; senhas marcadas como sensíveis pelo
gerenciador de senhas não entram). Escolher um item **só copia**: depois é colar onde quiser.

- **Cartões:** o tipo no topo; texto até 5 linhas com "…"; link em azul; código em verde; cor com a amostra; imagem com a
  prévia (o tamanho no topo). Os chips filtram por tipo e digitar já busca.
- **Fixados:** ficam no começo, com borda amarela, e sobrevivem ao "Limpar". O pino no canto (ou `Ctrl+P`) fixa e desafixa.
- **Limpar:** apaga o histórico inteiro, com um segundo clique para confirmar. Os fixados ficam.
- **Anotações:** a anotação escolhida fica em destaque à esquerda, pronta para escrever (título e texto no lugar, salvam
  sozinhos), com as 5 cores, "Copiar", "Fixar" e "Apagar" (com segundo clique) embaixo. À direita, a lista de todas, com a
  cor, o título e o começo do texto; clicar troca o destaque e arrastar uma linha muda a ordem dentro do grupo dela (as fixadas entre si, as outras entre si). "+ Nova anotação" cria uma no
  topo. As fixadas ficam no topo da lista, na ordem em que foram fixadas. A busca filtra pelo título e pelo texto.
- **Emoji:** a aba Emoji (ou `Tab`) mostra os emoji por grupo, com os recentes; a busca é pelo nome em inglês ("heart",
  "cat"). Clicar copia.

| Tecla | Faz |
|---|---|
| `←` `→` (e `↑` `↓` nos emoji) | Andam pelos cartões |
| `Enter` | Copia e fecha |
| `Ctrl+P` | Fixa ou desafixa |
| `Del` | Apaga do histórico |
| `Tab` / `Shift+Tab` | Troca de aba (Clipboard, Emoji, Anotações) |
| Digitar | Busca |
| `Esc` | Limpa a busca; de novo, fecha (escrevendo numa anotação, volta para a lista) |

Nas Anotações: `↑` `↓` escolhem na lista, `Enter` vai para o texto, `Ctrl+N` cria, `Ctrl+P` fixa e desafixa, `Del` arma o
apagar e o segundo `Del` apaga.

Clicar fora da gaveta ou `Super+V` de novo também fecha. Com a tela travada ela não abre.

Onde ficam os dados (fora do repo, só nesta máquina; pasta `700`, arquivos `600`):

| O quê | Onde |
|---|---|
| Histórico | `~/.cache/cliphist/db` (do `cliphist`) |
| Fixados | `~/.local/share/quickshell/clipboard/pins.json` e as imagens fixadas na mesma pasta |
| Anotações | `~/.local/share/quickshell/clipboard/notes.json` |
| Emoji recentes | `~/.local/share/quickshell/clipboard/emoji-recent.json` |
| Prévias de imagem | `$XDG_RUNTIME_DIR/quickshell-clip` (memória; apagadas ao fechar) |

**Atenção:** apagar `~/.local/share/quickshell` apaga os fixados e as anotações. Um arquivo que não dá para ler vira `.bak` e o
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
| `controlcenter` | `toggle` | `Super+I` (F9), `Super+A` |
| `powermenu` | `toggle` | `Super+X`, `Ctrl+Alt+Del` (a central já na energia) |
| `overview` | `toggle` | `Super+Tab`, 3 dedos ↑ |
| `lock` | `lock` | `Super+L` |
| `taskmanager` | `toggle` | `Ctrl+Shift+Esc` (painel do sistema da barra) |
| `cheatsheet` | `toggle` | `Super+F1` (hoje abre o `hypr-atalhos`) |

Outros alvos, para scripts:

| Comando | O que faz |
|---|---|
| `qs ipc call panel toggle <nome>` | Abre ou fecha um painel no monitor em foco: `control`, `network`, `volume`, `bluetooth`, `media`, `system` (`power` abre a central na energia) |
| `qs ipc call controlcenter open <seção>` | Abre a central com uma seção aberta: `wifi`, `bluetooth`, `updates`, `tailscale`, `mixer`, `power`, `background` (vazio: tudo dobrado) |
| `qs ipc call controlcenter stats` | O estado da central em JSON (aberta, seção); nunca nomes de rede, aparelho ou pacote |
| `qs ipc call updates check` | Procura atualizações agora, como "Verificar agora" (o `hypr-atualizar` chama no fim) |
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

### Configurações (Super+S)

`Super+S` abre as Configurações pela borda esquerda: as páginas numa coluna e, no topo, uma busca que acha qualquer opção.
As páginas: Tema e cores, Papel de parede, Fontes e animações, Barra, Bloqueio e login, Captura e clipboard, Energia,
Monitores, Teclado e mouse, Gestos, Atalhos, Apps padrão, Dispositivos e Sobre. Cada mudança vale na hora.

- **Onde fica o que você escolhe:** em `~/.config/dotfiles/settings.json`, só o que difere do padrão. Os padrões são o
  `hyprland/.config/quickshell/settings/defaults.json` do repo. A partir das escolhas o shell gera os arquivos que os
  outros programas leem, todos fora do git: `dotfiles_settings.lua`, `dotfiles_monitors.lua`, `dotfiles_apps.lua`,
  `dotfiles_autostart.lua` e `dotfiles_gestures.lua` (Hyprland), `hypridle.gerado.conf` e as cores do Kitty, do btop e do
  lazygit.
- **Exportar** (em Sobre) grava no `defaults.json` do repo o que você escolheu, menos o que é só desta máquina (como
  monitores, apps e teclado); depois é revisar o `git diff` antes do commit.
- **Restaurar tudo** (em Sobre) volta ao padrão do repo, menos o layout do teclado e os apps padrão do sistema. Antes
  guarda uma cópia (`settings.json.bak-…`, ficam as três últimas) e dá para desfazer por 30 segundos. "Montar sozinho ao
  conectar" volta a ligado (vale para o próximo pendrive). Cada grupo da página tem também o seu "Restaurar padrão".
- **Monitores:** resolução, escala e posição valem na hora e voltam sozinhas em 15 segundos se você não confirmar. A volta
  é um timer do systemd, fora do shell: funciona mesmo se o shell travar.
- **O que pede senha:** a janela de senha do sistema (polkit) aparece para trocar o layout do teclado do sistema
  (`localectl`), para ligar ou desligar a busca de impressoras na rede (o avahi, pelo systemd) e para adicionar ou mudar
  uma impressora no `system-config-printer` (pelo `cups-pk-helper`); depois de digitada, vale por alguns minutos. Montar,
  abrir e ejetar pendrive, a impressora padrão, a página de teste, cancelar o seu trabalho e o limite da bateria não pedem
  senha.

### Luz noturna

Em Configurações → Monitores: liga sozinha no horário escolhido (pode passar da meia-noite) e deixa a tela mais quente
(6500 K é a cor normal; quanto menor, mais quente). É o `hyprsunset`, aberto e fechado pelo próprio shell; sem horário
automático por nascer e pôr do sol.

### Apps padrão e iniciar com o sistema

Em Configurações → Apps padrão, cada linha (Navegador, Arquivos, Terminal, Imagens, Vídeos, Músicas, Texto, PDF e, quando
algum app instalado abre o tipo, Documentos, Planilhas, Apresentações, Imagens vetoriais, Fotos RAW e Desenhos técnicos)
lista só os apps que abrem aquele tipo e mostra o que o sistema usa agora (`xdg-mime`). Trocar ali muda o padrão do
sistema na hora. Terminal e Arquivos valem para os atalhos Super+Enter e Super+E; a lista de atalhos, as regras de janela e
o btop continuam no Kitty. Em "Iniciar com o sistema" ficam o ArtCraft Launcher (escondido, ligado por padrão) e até 16
apps que abrem quando você entra na sessão, nunca numa recarga. O que você escolhe fica em
`~/.config/hypr/dotfiles_apps.lua` e `dotfiles_autostart.lua`, só com os nomes dos apps, fora do git; os apps abrem pelo
uwsm (ou pelo `gtk-launch`, fora dele).

### Dispositivos e impressoras

Em Configurações → Dispositivos:

- **Impressoras:** cada fila com o estado, a conexão (rede ou USB) e a fila de impressão, com Tornar padrão, Página de
  teste e Cancelar (só os seus trabalhos). O serviço de impressão (CUPS) só sobe quando algo imprime. "Adicionar
  impressora" abre o `system-config-printer`. Impressora moderna funciona sem driver. A busca de impressoras na rede
  (avahi) fica desligada e só liga no interruptor da página, sem anunciar este computador; depois de adicionada pelo
  endereço (IP ou `ipps://`), a impressora funciona com a busca desligada. Nomes `.local` podem ser imitados numa rede
  compartilhada, por isso uma fila criada a partir da busca aparece marcada como "da rede" e não serve de padrão.
- **Pendrives e HDs:** montar, abrir e ejetar (ejetar nunca força: com um arquivo aberto, avisa). "Montar sozinho ao
  conectar" vale só para FAT32 e exFAT plugados com a sessão destravada; NTFS, ext4 e btrfs montam pelo botão, e o que
  foi plugado com a tela bloqueada espera o botão mesmo depois de destravar. Tudo monta sempre sem permissão de executar
  (`noexec`, `nosuid`, `nodev` e `nosymfollow`, em `/etc/udisks2/mount_options.conf`, do `install.sh`): nenhum arquivo
  do pendrive roda direto como programa.
- **Conectados por USB:** só os nomes, sem número de série; um pendrive que também age como teclado é marcado.

O Thunar (e o tumbler, que faz as miniaturas) só gera miniatura de imagem (`common/.config/tumbler/tumbler.rc`): vídeo,
PDF, fontes, documentos e o resto ficam sem, para um arquivo de pendrive não ser lido só por abrir a pasta.

No Hyprland o ícone de rede (nm-applet) e o da fila de impressão não sobem (o `install.sh` mascara as duas unidades do
autostart): a rede fica no painel da barra e na central de controle, as impressoras em Configurações → Dispositivos. No
XFCE eles continuam. Para voltar: `systemctl --user unmask 'app-nm\x2dapplet@autostart.service' 'app-print\x2dapplet@autostart.service'`.

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

Escolhidos em Configurações → Energia, um conjunto na tomada e outro na bateria (o shell usa o da fonte de agora e troca
sozinho ao ligar ou tirar o carregador). Os padrões são os do plano "Equilibrado" do Windows:

| Parado há | Acontece |
|---|---|
| 4 min 30 s | A tela escurece, com uma contagem de 30 s até travar (o "aviso antes de travar") |
| 5 min | Trava |
| 5 min 10 s | Apaga a tela (com a trava ligada, sempre no mínimo 10 s depois de travar) |
| 60 min | Suspende, só na bateria (na tomada o padrão é "Nunca"); trava antes |

Qualquer tecla ou movimento do mouse desfaz o escurecer. Um vídeo tocando segura tudo; música não.

O shell grava os tempos em `~/.config/hypr/hypridle.gerado.conf` (fora do git) e reinicia o `hypridle` se ele estiver rodando.
O `hypridle` sobe pelo `hypr-hypridle` (drop-in `gerado.conf` do serviço), que junta o bloco `general` do `hypridle.conf` do
repo com os tempos do shell. Ele só aceita o arquivo do shell se cada linha passar numa lista fechada (tempos de 30 s a 24 h e
os comandos de sempre); qualquer coisa fora disso, ou o arquivo faltando, volta aos tempos do `hypridle.conf`. O travar antes
de suspender e o travar ao fechar a tampa ficam sempre no `hypridle.conf` do repo.

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
