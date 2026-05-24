extends Area2D
# Hitbox no topo da cabeca do inimigo: apenas da bounce no player quando ele
# pula em cima. NAO causa mais dano ao inimigo - o dano agora so vem da
# area de ataque do player (LMB).

func _on_body_entered(body: Node2D) -> void:
	if body.name != "player":
		return
	# Bounce no player ao pular em cima
	body.velocity.y = body.JUMP_FORCE


func _on_body_exited(_body: Node2D) -> void:
	# Placeholder para a conexao body_exited definida em hitbox.tscn,
	# evita warning de "missing function".
	pass
