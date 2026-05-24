extends Node
# Singleton (autoload) responsavel por trocar de cena com efeito de fade preto.
# Uso: SceneManager.change_scene("res://scenes/world_02.tscn")

const FADE_DURATION := 0.4

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _is_transitioning := false


func _ready() -> void:
	# Cria a camada de fade dinamicamente para nao depender de cena externa.
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100  # acima de tudo (UI inclusive)
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.anchor_right = 1.0
	_fade_rect.anchor_bottom = 1.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.modulate.a = 0.0  # comeca invisivel
	_fade_layer.add_child(_fade_rect)


func change_scene(target_path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	# Escurece a tela
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished

	# Troca de cena
	var err := get_tree().change_scene_to_file(target_path)
	if err != OK:
		push_error("SceneManager: falha ao trocar para %s (erro %d)" % [target_path, err])

	# Espera um frame para a nova cena montar antes de clarear
	await get_tree().process_frame

	# Clareia
	tween = create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished

	_is_transitioning = false
