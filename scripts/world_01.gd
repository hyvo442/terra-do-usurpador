extends Node2D
# Script usado por todos os mundos (world_01, world_02, world_03...).
# Configura a camera para seguir o player e calcula automaticamente os
# limites da camera com base no TileMap "level", se houver. Isso evita
# que a camera ultrapasse o mapa e faz com que ela fique "recuada" em
# relacao ao player quando ele chega perto dos cantos do mapa.

const FALLBACK_TILE_SIZE := 16

@onready var player := $player as CharacterBody2D
@onready var camera := $camera as Camera2D


func _ready() -> void:
	player.follow_camera(camera)
	_setup_camera()


func _setup_camera() -> void:
	# Suaviza o movimento da camera para reforcar a sensacao de "recuo"
	# perto das bordas do mapa.
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0

	# Calcula os limites da camera a partir do TileMap "level", se ele
	# existir nessa cena. Mundos sem TileMap podem ter limites definidos
	# manualmente na cena.
	var level := get_node_or_null("level")
	if level == null or not (level is TileMap):
		return

	var tile_map: TileMap = level
	var rect: Rect2i = tile_map.get_used_rect()
	if rect.size == Vector2i.ZERO:
		return

	var tile_size: float = FALLBACK_TILE_SIZE
	if tile_map.tile_set != null:
		tile_size = float(tile_map.tile_set.tile_size.x)

	# map_to_local devolve o CENTRO de um tile, entao tiramos meio tile
	# para obter as bordas reais do mapa.
	var top_left: Vector2 = tile_map.to_global(tile_map.map_to_local(rect.position)) \
			- Vector2(tile_size * 0.5, tile_size * 0.5)
	var bottom_right: Vector2 = tile_map.to_global(tile_map.map_to_local(rect.end)) \
			- Vector2(tile_size * 0.5, tile_size * 0.5)

	camera.limit_left = int(top_left.x)
	camera.limit_top = int(top_left.y)
	camera.limit_right = int(bottom_right.x)
	camera.limit_bottom = int(bottom_right.y)
