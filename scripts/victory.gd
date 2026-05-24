extends CanvasLayer
# Tela de vitoria - fundo preto cobrindo a tela inteira com a mensagem final.
# Eh exibida quando o player encosta no trono do world_03 depois de ter
# derrotado o dragao_chefe (com os 2 segundos de delay aplicados em
# dragao_chefe.gd antes do sinal "died").

func _ready() -> void:
	# Pausa o jogo enquanto a tela de vitoria estiver no ar (impede que o
	# player continue se mexendo, leve dano, etc).
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
