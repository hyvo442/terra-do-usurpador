# Terra do Usurpador

## Sobre o jogo

- **Nome:** Terra do Usurpador
- **Gênero:** RPG de Ação 2D / Side-scroller (Plataforma)
- **Motor:** Godot 4
- **Estilo visual:** Pixel art 32 bits (inspiração Metroidvania clássica)

## Tema e enredo

Em um reino dominado pela tirania, um rei cruel oprime seu povo com altos
impostos, fome e execuções. A população vive aterrorizada, pois o rei comanda
um exército imenso e um dragão devastador que aniquila qualquer um que ouse
desafiá-lo.

O protagonista, um jovem camponês, perde sua mãe para a fome causada pela
miséria do reino. Tomado pela revolta, ele veste uma armadura azul — em
contraste com o vermelho dos cavaleiros do rei — e parte em uma jornada de
vingança. Ele enfrenta cavaleiros pelo caminho, alcança o castelo e trava uma
batalha épica contra o dragão. Ao derrotá-lo e matar o rei, ele encerra a
tirania e se torna o novo soberano daquela terra.

## Como rodar

1. Instale a [Godot 4.6](https://godotengine.org/download) ou superior.
2. Clone este repositório.
3. Abra o `project.godot` pela Godot.
4. Pressione **F5** para rodar a partir da cena principal (`world_01.tscn`).

## Controles

| Ação                  | Tecla / Botão        |
| --------------------- | -------------------- |
| Mover                 | `←` / `→`            |
| Pular                 | `Espaço`             |
| Atacar (espada)       | Botão esquerdo mouse |
| Defender              | `Q`                  |
| Interagir / Avançar diálogo | `I` / `O`      |

## Estrutura do projeto

```
.
├── assets/      # Tilesets, planos de fundo, UI, imagens diversas
├── resources/   # Themes (.tres) compartilhados
├── scenes/      # .tscn — cenas do jogo
├── scripts/     # .gd — lógica do jogo
├── shaders/     # .gdshader — shaders (ex: nuvens em movimento)
└── sprites/     # Animações dos personagens, organizadas por papel
```

### Mundos

- **world_01** — vila tomada por cavaleiros do rei e o primeiro arqueiro.
- **world_02** — caminho até o castelo, com mais cavaleiros e um arqueiro.
- **world_03** — sala do trono, onde o jogador enfrenta o dragão chefe.

### Personagens / inimigos

| Cena                  | Papel                                                |
| --------------------- | ---------------------------------------------------- |
| `player.tscn`         | Jovem camponês de armadura azul.                     |
| `cavaleiro.tscn`      | Cavaleiro vermelho do rei, ataca corpo-a-corpo.      |
| `arqueiro.tscn`       | Soldado arqueiro, ataca à distância com flechas.     |
| `dragao_chefe.tscn`   | Dragão final, combina ataque à distância e corpo-a-corpo. |

### Projéteis

- `flecha.tscn` — flecha disparada pelo arqueiro.
- `bola_de_fogo.tscn` — projétil de fogo cuspido pelo dragão chefe.

## Telas e UI

- `pause_menu.tscn` — menu de pausa.
- `game_over.tscn` — tela de derrota.
- `victory.tscn` — tela de vitória ao chegar no trono após derrotar o chefe.
- `dialog_box.tscn` — caixa de diálogo (NPC / placa de aviso).

## Sistemas

- **Player HUD:** numerador de vidas embutido no `player.tscn`, presente em
  todos os mundos.
- **Boss HUD:** barra e numerador de HP do dragão chefe, exclusivos do
  `world_03`.
- **Transição entre cenas:** `SceneManager` (autoload) faz fade-in/out preto.
- **Sistema de diálogo:** `DialogManager` (autoload) controla as falas de NPCs
  e placas (`warning_sign.gd`).

## Créditos de assets

- Tilesets e UI: pacote *Mini FX, Items & UI* / *Seasonal Tilesets*
  (incluídos em `assets/`).
- Sprites de personagens: incluídos em `sprites/` (personagem, cavaleiro,
  arqueiro, dragão chefe).
