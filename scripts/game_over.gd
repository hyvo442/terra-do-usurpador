extends CanvasLayer

# Tela de Game Over. Mostra duas opcoes: jogar de novo (reinicia a cena atual)
# e sair do jogo.

func _ready() -> void:
	visible = false
	# Permite que o menu funcione mesmo com o jogo pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS


# Chamado quando o player morre para exibir a tela e pausar o jogo.
func show_game_over() -> void:
	visible = true
	get_tree().paused = true


func _on_restart_btn_pressed() -> void:
	# Despausa antes de recarregar para evitar que a nova cena ja venha pausada.
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_btn_pressed() -> void:
	get_tree().quit()
