extends CharacterBody2D
# Inimigo corpo-a-corpo.
# Fica em idle no spawn. Quando o player entra na detection_area ele persegue.
# Quando o player fica perto o suficiente, ele executa a animacao de ataque
# e SO causa dano ao player se o attack_hitbox estiver ativo (durante a janela
# de dano da animacao). Encostar no corpo do inimigo NAO causa dano.
# Pode ser morto se o player pular em cima da sua cabeca (hitbox padrao).

const SPEED := 75.0            # ajustado para o tamanho 1.5x
const ATTACK_RANGE := 33.0     # distancia (em pixels) para iniciar o ataque (1.5x do original)
const ATTACK_COOLDOWN := 1.6   # intervalo entre ataques (0.6s base + 1s extra)
# Frames da animacao "attack" em que o golpe efetivamente machuca.
# A animacao tem 20 frames apos cortar 5 iniciais; o golpe acontece nos
# frames 7-9 (correspondem aos antigos 12-14 antes do corte).
const ATTACK_DAMAGE_FRAMES := [7, 8, 9]

enum State { IDLE, CHASE, ATTACK, HURT }

@onready var anim := $anim as AnimatedSprite2D
@onready var detection_area := $detection_area as Area2D
@onready var attack_hitbox := $attack_hitbox as Area2D
@onready var hitbox := $hitbox as Area2D                # area do "stomp" / bounce no topo da cabeca

var state: int = State.IDLE
var player: Node2D = null
var direction := -1            # 1 = direita, -1 = esquerda
var _attack_cooldown := 0.0
var _hit_this_attack := false  # garante que cada ataque machuque o player no maximo uma vez


func _ready() -> void:
	detection_area.body_entered.connect(_on_player_detected)
	detection_area.body_exited.connect(_on_player_lost)
	anim.animation_finished.connect(_on_anim_finished)
	anim.frame_changed.connect(_on_anim_frame_changed)
	anim.play("idle")


func _physics_process(delta: float) -> void:
	# Gravidade para o inimigo nao flutuar
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta

	match state:
		State.IDLE:
			velocity.x = 0
			_safe_play("idle")
			if is_instance_valid(player):
				state = State.CHASE

		State.CHASE:
			if not is_instance_valid(player):
				state = State.IDLE
				velocity.x = 0
			else:
				_face_player()
				var dist_x: float = abs(player.global_position.x - global_position.x)
				if dist_x <= ATTACK_RANGE and _attack_cooldown <= 0.0 and is_on_floor():
					_start_attack()
				else:
					velocity.x = direction * SPEED
					_safe_play("run")

		State.ATTACK:
			# Fica parado durante o ataque, a animacao manda no resto.
			velocity.x = 0

		State.HURT:
			velocity.x = 0

	move_and_slide()


# Vira o sprite para encarar o player e ajusta a posicao do attack_hitbox.
func _face_player() -> void:
	if not is_instance_valid(player):
		return
	direction = 1 if player.global_position.x > global_position.x else -1
	# Sprite default do cavaleiro olha pra esquerda; espelha quando vai pra direita.
	anim.flip_h = (direction == -1)
	# Mantem o attack_hitbox sempre na frente do inimigo
	attack_hitbox.position.x = abs(attack_hitbox.position.x) * direction


func _start_attack() -> void:
	state = State.ATTACK
	_hit_this_attack = false
	_attack_cooldown = ATTACK_COOLDOWN
	velocity.x = 0
	_safe_play("attack")


# Aplica dano no player se ele estiver sobreposto ao attack_hitbox durante
# a janela de dano do ataque. Cada ataque so machuca uma vez.
func _try_damage_player() -> void:
	if _hit_this_attack:
		return
	for body in attack_hitbox.get_overlapping_bodies():
		if body.name == "player" and body.has_method("take_damage"):
			var knockback := Vector2(200.0 * direction, -200.0)
			body.take_damage(knockback)
			_hit_this_attack = true
			break


# ---------------- Sinais ----------------

func _on_player_detected(body: Node2D) -> void:
	if body.name == "player":
		player = body
		if state == State.IDLE:
			state = State.CHASE


func _on_player_lost(body: Node2D) -> void:
	if body == player:
		player = null
		if state == State.CHASE:
			state = State.IDLE


func _on_anim_finished() -> void:
	if anim.animation == "attack":
		if is_instance_valid(player):
			state = State.CHASE
		else:
			state = State.IDLE
	elif anim.animation == "hurt":
		queue_free()


func _on_anim_frame_changed() -> void:
	# Aplica dano apenas durante os frames de dano do golpe.
	if state == State.ATTACK and anim.animation == "attack":
		if anim.frame in ATTACK_DAMAGE_FRAMES:
			_try_damage_player()


# ---------------- Stomp (pulo na cabeca) ----------------
# Chamado pela hitbox.tscn quando o player pula em cima.
func on_hit() -> void:
	if state == State.HURT:
		return
	state = State.HURT
	velocity = Vector2.ZERO
	# Desativa todas as hitboxes durante o hurt, para evitar interacoes indesejadas
	# (player nao pula em cabeca de inimigo morrendo, ataque ja iniciado nao
	# continua machucando, etc).
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	attack_hitbox.set_deferred("monitoring", false)
	attack_hitbox.set_deferred("monitorable", false)
	_safe_play("hurt")


# ---------------- Util ----------------

func _safe_play(anim_name: StringName) -> void:
	if anim.animation != anim_name:
		anim.play(anim_name)
