extends CharacterBody2D

const ATTACK_RANGE := 250.0     # Distância para ele começar a atirar
const ATTACK_COOLDOWN := 2.0    # Intervalo de 2 segundos entre os ataques

@export var flecha_scene: PackedScene  # Arraste a cena da bola de fogo aqui no Inspector

@onready var anim := $anim as AnimatedSprite2D
@onready var attack_timer := $attack_timer as Timer
@onready var flecha_spawn := $flecha_spawn as Marker2D
@onready var detection_area := $detection_area as Area2D
@onready var hitbox := $hitbox as Area2D            # area do "stomp" no topo da cabeca

var player: Node2D = null
var direction := -1  # -1 = esquerda, 1 = direita
var can_attack := true
var is_hurt := false


func _ready() -> void:
	detection_area.body_entered.connect(_on_player_detected)
	detection_area.body_exited.connect(_on_player_lost)
	attack_timer.timeout.connect(_on_attack_cooldown_finished)
	anim.animation_finished.connect(_on_anim_finished)
	anim.play("idle")


func _physics_process(delta: float) -> void:
	# Aplica gravidade para ele não flutuar caso o chão mude
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	# Se ele levou dano, trava tudo e não faz mais nada
	if is_hurt:
		velocity.x = 0
		move_and_slide()
		return

	# Lógica de detecção e ataque
	if is_instance_valid(player):
		# Sempre vira na direção do jogador de forma inteligente
		direction = 1 if player.global_position.x > global_position.x else -1
		anim.flip_h = (direction == -1) # Se continuar fazendo moonwalk, mude para (direction == 1)
		
		# Ajusta a posição do focinho de onde sai o fogo
		flecha_spawn.position.x = abs(flecha_spawn.position.x) * direction

		# Verifica a distância. Se estiver no alcance e puder atacar, ele atira!
		var dist := global_position.distance_to(player.global_position)
		if dist <= ATTACK_RANGE and can_attack:
			_shoot()
	else:
		_safe_play("idle")

	move_and_slide()


func _shoot() -> void:
	can_attack = false
	_safe_play("attack")
	# REMOVEMOS o _spawn_flecha daqui. Agora ele apenas toca a animação.
	
	# O timer de 2 segundos começa a contar a partir do momento do disparo
	attack_timer.start(ATTACK_COOLDOWN)


func _spawn_flecha() -> void:
	if not flecha_scene:
		push_warning("arqueiro: flecha_scene nao foi definida no Inspector")
		return
	var fb := flecha_scene.instantiate()
	get_parent().add_child(fb)
	fb.global_position = flecha_spawn.global_position
	if fb.has_method("set_direction"):
		fb.set_direction(direction)


# Chamado quando o player pula na cabeça dele
func on_hit() -> void:
	if is_hurt:
		return
	is_hurt = true
	# Desativa a hitbox para evitar interacoes indesejadas durante o hurt
	# (player nao pula em cabeca de inimigo morrendo).
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	_safe_play("hurt")


func _on_anim_finished() -> void:
	if anim.animation == "hurt":
		queue_free()
		
	elif anim.animation == "attack":
		_spawn_flecha() # A bola de fogo nasce EXATAMENTE quando o ataque termina!
		_safe_play("idle") # O dragão volta a ficar em pose de espera suavemente


func _on_player_detected(body: Node2D) -> void:
	if body.name == "player":
		player = body


func _on_player_lost(body: Node2D) -> void:
	if body == player:
		player = null


func _on_attack_cooldown_finished() -> void:
	can_attack = true


func _safe_play(name: StringName) -> void:
	if anim.animation != name:
		anim.play(name)
		
