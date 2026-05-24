extends Node2D
# Script especifico do world_03:
# - Faz o mesmo setup de camera do world_01.gd (compartilhamos a logica copiando
#   por motivos de simplicidade: o world_01.gd eh usado pelos outros mundos).
# - Mostra um HUD inferior com o HP do chefe (dragao_chefe) e atualiza em
#   tempo real ouvindo o sinal "hp_changed" do chefe.
# - Quando o sinal "died" eh emitido pelo chefe (2 segundos depois da morte),
#   habilita a area do trono. Se o player encostar nela, abre a tela de vitoria.

const FALLBACK_TILE_SIZE := 16
const VictoryScene: PackedScene = preload("res://scenes/victory.tscn")

@onready var player := $player as CharacterBody2D
@onready var camera := $camera as Camera2D
@onready var chefe := $dragao_chefe as CharacterBody2D
@onready var boss_hp_bar := $boss_hud/hp_container/hp_bar as ProgressBar
@onready var boss_hp_label := $boss_hud/hp_container/hp_label as Label
@onready var throne_area := $throne_area as Area2D

var _boss_defeated := false
var _victory_shown := false


func _ready() -> void:
	player.follow_camera(camera)
	_setup_camera()

	# HUD do chefe: assina o sinal de HP. O dragao_chefe.gd ja faz um
	# emit_signal diferido no _ready() dele com o HP inicial, entao o HUD
	# se sincroniza sozinho na primeira atualizacao.
	if chefe:
		chefe.hp_changed.connect(_on_boss_hp_changed)
		chefe.died.connect(_on_boss_died)

	# Area do trono comeca desativada - so libera depois do chefe morrer
	# (com os 2 segundos de delay aplicados no dragao_chefe.gd).
	if throne_area:
		throne_area.monitoring = false
		throne_area.body_entered.connect(_on_throne_area_entered)


func _setup_camera() -> void:
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0

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

	var top_left: Vector2 = tile_map.to_global(tile_map.map_to_local(rect.position)) \
			- Vector2(tile_size * 0.5, tile_size * 0.5)
	var bottom_right: Vector2 = tile_map.to_global(tile_map.map_to_local(rect.end)) \
			- Vector2(tile_size * 0.5, tile_size * 0.5)

	camera.limit_left = int(top_left.x)
	camera.limit_top = int(top_left.y)
	camera.limit_right = int(bottom_right.x)
	camera.limit_bottom = int(bottom_right.y)


# --- HUD do chefe ---

func _on_boss_hp_changed(current_hp: int, max_hp: int) -> void:
	if boss_hp_bar:
		boss_hp_bar.max_value = max_hp
		boss_hp_bar.value = max(current_hp, 0)
	if boss_hp_label:
		boss_hp_label.text = "Chefe: %d / %d" % [max(current_hp, 0), max_hp]


# --- Fim de jogo ---

func _on_boss_died() -> void:
	# Sinal "died" eh emitido 2s depois da morte do chefe (regra dele).
	# Libera o trono e tambem esconde o HUD do chefe.
	_boss_defeated = true
	var boss_hud := get_node_or_null("boss_hud") as CanvasLayer
	if boss_hud:
		boss_hud.visible = false
	if throne_area:
		throne_area.monitoring = true
		# Caso o player ja esteja dentro da area do trono no momento em que
		# o sinal chega (ex: ele andou ate la antes do delay de 2s terminar),
		# o body_entered nao dispara - precisamos verificar os bodies
		# sobrepostos manualmente no proximo frame de fisica.
		await get_tree().physics_frame
		if not _boss_defeated:
			return  # seguranca caso o estado seja resetado
		for body in throne_area.get_overlapping_bodies():
			if body.name == "player":
				_show_victory()
				return


func _on_throne_area_entered(body: Node2D) -> void:
	if not _boss_defeated:
		return
	if body.name != "player":
		return
	_show_victory()


func _show_victory() -> void:
	if _victory_shown:
		return
	_victory_shown = true
	# Desabilita a area pra nao disparar varias vezes.
	if throne_area:
		throne_area.set_deferred("monitoring", false)
	var victory := VictoryScene.instantiate()
	add_child(victory)
