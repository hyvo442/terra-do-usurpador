extends Node2D

@onready var area_sign = $area_sign
@onready var texture = $texture

const lines: Array[String] = [
	"olá aventureiro", 
	"algumas teclas rapidas para voce se familiarizar sao:", 
	"aperte o botao esquerdo do mouse para atacar ",
	"aperte Q para ficar em defesa",
	"Boa sorte!"
]

# Variável para controlar se o jogador está perto da placa
var player_in_area := false

func _ready() -> void:
	texture.hide() # Garante que o ícone começa escondido
	
	# Conecta os sinais da área via código (caso não tenha conectado pelo editor)
	area_sign.body_entered.connect(_on_area_sign_body_entered)
	area_sign.body_exited.connect(_on_area_sign_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	# Só interage se o jogador estiver na área e apertar o botão
	if player_in_area && event.is_action_pressed("interact"):
		if !DialogManager.is_message_active:
			texture.hide() # Esconde o balão enquanto conversa
			DialogManager.start_message(global_position, lines)

# Quando o jogador entra na área da placa
func _on_area_sign_body_entered(body: Node2D) -> void:
	player_in_area = true
	if !DialogManager.is_message_active:
		texture.show() # Mostra o ícone de mensagem

# Quando o jogador sai da área da placa
func _on_area_sign_body_exited(body: Node2D) -> void:
	player_in_area = false
	texture.hide() # Esconde o ícone de mensagem
