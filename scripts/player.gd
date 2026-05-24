extends CharacterBody2D
# Player com sistema de defesa (Q) e ataque (LMB).
#
# Defesa: enquanto Q estiver pressionado, o jogador para, toca "defense" e
# tem a hurtbox padrao desligada. Em seu lugar, ficam ativas duas areas:
#   - defense_back_hurtbox: metade traseira - recebe dano normalmente.
#   - defense_front_block: metade dianteira - anula qualquer dano.
#
# Ataque: ao clicar com o LMB, toca "atack" e ativa o attack_hitbox (uma area
# estendida na frente). O player pode atacar andando, mas com velocidade
# reduzida. Inimigos sobrepostos ao attack_hitbox durante os frames de
# impacto recebem on_hit() (nao ha mais dano de stomp).

const SPEED := 200.0
const ATTACK_SPEED_MULTIPLIER := 0.45  # velocidade durante o ataque
const JUMP_VELOCITY := -400.0
const JUMP_FORCE: float = -400.0  # usado pelo hitbox dos inimigos (bounce)

# Frames da animacao "atack" em que o golpe efetivamente machuca.
# Sao os frames em que a espada esta visivel a frente do corpo (impacto).
# O sprite atual tem 9 frames; os de impacto sao 6, 7 e 8.
# Ajuste estes valores se trocar o sprite de ataque.
const ATTACK_DAMAGE_FRAMES := [6, 7, 8]

# Posicoes de referencia (lado "direito"), serao espelhadas pelo facing.
# Estes valores acompanham as posicoes originais das colisoes na cena
# multiplicadas pelo SIZE_BOOST aplicado (atual: 1.5x). Se mudar o boost na
# geracao das cenas, ajuste aqui tambem.
const _DEFENSE_BACK_X := -7.5
const _DEFENSE_FRONT_X := 7.5
const _ATTACK_HITBOX_X := 36.0

const GameOverScene := preload("res://scenes/game_over.tscn")

@onready var remote_transform := $remote as RemoteTransform2D
@onready var animation := $animacoes as AnimatedSprite2D
@onready var hurtbox := $hurtbox as Area2D
@onready var hurtbox_shape := $hurtbox/CollisionShape2D as CollisionShape2D
@onready var defense_back := $defense_back_hurtbox as Area2D
@onready var defense_back_shape := $defense_back_hurtbox/CollisionShape2D as CollisionShape2D
@onready var defense_front := $defense_front_block as Area2D
@onready var defense_front_shape := $defense_front_block/CollisionShape2D as CollisionShape2D
@onready var attack_hitbox := $attack_hitbox as Area2D
@onready var attack_hitbox_shape := $attack_hitbox/CollisionShape2D as CollisionShape2D
@onready var lives_label := $hud/lives_container/lives_label as Label

@export var player_life := 10

var knockback_vector := Vector2.ZERO
var is_jumping := false
var is_defending := false
var is_attacking := false
var facing := 1                      # 1 = direita, -1 = esquerda
var _enemies_hit_this_attack: Array = []   # cada ataque so machuca cada inimigo uma vez


func _ready() -> void:
	animation.animation_finished.connect(_on_animation_finished)
	# Inicia em modo normal
	_set_defense_active(false)
	attack_hitbox_shape.disabled = true
	_update_facing_areas()
	_update_lives_label()


# Atualiza o numerador de vidas exibido no HUD.
func _update_lives_label() -> void:
	if lives_label:
		lives_label.text = "Vidas: %d" % max(player_life, 0)


func _physics_process(delta: float) -> void:
	# Gravidade
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Pulo (so se nao estiver defendendo)
	if not is_defending and Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		is_jumping = true
	elif is_on_floor():
		is_jumping = false

	# --- Defesa ---
	# A defesa tem prioridade sobre o ataque para o estado visual,
	# mas o player nao pode iniciar defesa enquanto esta atacando.
	var want_defense := Input.is_action_pressed("defense")
	if want_defense and not is_attacking and not is_defending:
		_enter_defense()
	elif not want_defense and is_defending:
		_exit_defense()

	# --- Ataque ---
	if not is_attacking and not is_defending and Input.is_action_just_pressed("atack"):
		_start_attack()

	# --- Movimento ---
	var direction := 0.0
	if not is_defending:
		direction = Input.get_axis("ui_left", "ui_right")

	if direction != 0.0:
		var speed := SPEED
		if is_attacking:
			speed = SPEED * ATTACK_SPEED_MULTIPLIER
		velocity.x = direction * speed
		# Atualiza a direcao que o player encara (so muda quando o player
		# realmente esta andando, para nao virar para tras durante um ataque).
		if not is_attacking and not is_defending:
			facing = int(sign(direction))
			# Usa flip_h em vez de mexer em scale.x (que causaria distorcao,
			# ja que o nó tem scale 0.x e atribuir 1/-1 deformava o sprite).
			# Sprite default do personagem olha pra direita.
			animation.flip_h = (facing == -1)
			_update_facing_areas()
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# --- Animacao ---
	if is_defending:
		_play_anim("defense")
	elif is_attacking:
		_play_anim("atack")
		# Durante os frames de impacto, aplica dano em inimigos sobrepostos
		if animation.frame in ATTACK_DAMAGE_FRAMES:
			_try_damage_enemies()
	elif is_jumping or not is_on_floor():
		_play_anim("jump")
	elif direction != 0.0:
		_play_anim("run")
	else:
		_play_anim("idle")

	# Knockback (de quando o player toma dano)
	if knockback_vector != Vector2.ZERO:
		velocity = knockback_vector

	move_and_slide()


# --- Helpers de estado ---

func _enter_defense() -> void:
	is_defending = true
	velocity.x = 0
	_set_defense_active(true)


func _exit_defense() -> void:
	is_defending = false
	_set_defense_active(false)


# Liga / desliga a hurtbox padrao versus as hurtboxes de defesa.
func _set_defense_active(active: bool) -> void:
	hurtbox_shape.set_deferred("disabled", active)
	defense_back_shape.set_deferred("disabled", not active)
	defense_front_shape.set_deferred("disabled", not active)


func _start_attack() -> void:
	is_attacking = true
	_enemies_hit_this_attack.clear()
	attack_hitbox_shape.set_deferred("disabled", false)
	# Reinicia a animacao do zero
	animation.stop()
	animation.play("atack")


func _end_attack() -> void:
	is_attacking = false
	attack_hitbox_shape.set_deferred("disabled", true)


# Aplica on_hit em inimigos sobrepostos ao attack_hitbox durante o golpe.
func _try_damage_enemies() -> void:
	for body in attack_hitbox.get_overlapping_bodies():
		if body == self:
			continue
		if body in _enemies_hit_this_attack:
			continue
		if body.has_method("on_hit"):
			body.on_hit()
			_enemies_hit_this_attack.append(body)


# Atualiza posicoes das areas que dependem da direcao que o player encara.
func _update_facing_areas() -> void:
	defense_back_shape.position.x = _DEFENSE_BACK_X * facing
	defense_front_shape.position.x = _DEFENSE_FRONT_X * facing
	attack_hitbox_shape.position.x = _ATTACK_HITBOX_X * facing


# Helper para trocar de animacao sem reiniciar quando ja esta tocando a mesma.
# Os sprites novos (personagem) tem tamanhos parecidos entre todas as animacoes,
# entao nao precisamos mais corrigir offset manualmente como antes.
# Se em algum momento uma animacao especifica precisar de offset, faca-o
# diretamente no editor (no proprio frame ou na propriedade offset do nó).
func _play_anim(anim_name: StringName) -> void:
	if animation.animation != anim_name:
		animation.play(anim_name)


# --- Sinais de animacao ---

func _on_animation_finished() -> void:
	if animation.animation == "atack":
		_end_attack()


# --- Recebimento de dano ---

func _on_hurtbox_body_entered(body: Node2D) -> void:
	# Hurtbox padrao - dano por contato com inimigos.
	# Apenas inimigos no grupo "contact_damage" causam dano por contato.
	# Hoje so o dragao_chefe esta nesse grupo (cavaleiro e arqueiro nao machucam por encostar).
	if body.is_in_group("contact_damage"):
		_apply_contact_damage(body)


func _on_defense_back_body_entered(body: Node2D) -> void:
	# Pegou um inimigo encostando nas costas durante a defesa - leva dano.
	# Mesma regra do hurtbox principal: so quem esta no grupo contact_damage.
	if body.is_in_group("contact_damage"):
		_apply_contact_damage(body)


func _apply_contact_damage(body: Node2D) -> void:
	if body.global_position.x > global_position.x:
		take_damage(Vector2(-200, -200))
	else:
		take_damage(Vector2(200, -200))


func take_damage(knockback_force := Vector2.ZERO, duration := 0.25):
	# Se estiver defendendo e o golpe veio de frente, bloqueia.
	if is_defending and knockback_force.x != 0:
		# Altere a linha 221 para isto:
		var attacker_from_front: bool = sign(knockback_force.x) != float(facing)
		if attacker_from_front:
			return  # bloqueado

	player_life -= 1
	_update_lives_label()
	if player_life <= 0:
		_show_game_over()
		queue_free()
		return

	if knockback_force != Vector2.ZERO:
		knockback_vector = knockback_force

		var knockback_tween := get_tree().create_tween()
		knockback_tween.parallel().tween_property(self, "knockback_vector", Vector2.ZERO, duration)
		animation.modulate = Color(1, 0, 0, 1)
		knockback_tween.parallel().tween_property(animation, "modulate", Color(1, 1, 1, 1), duration)


# --- Camera ---

func follow_camera(camera):
	var camera_path = camera.get_path()
	remote_transform.remote_path = camera_path


# --- Game Over ---

func _show_game_over() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	if current_scene.has_node("game_over"):
		return

	var game_over := GameOverScene.instantiate()
	game_over.name = "game_over"
	current_scene.add_child(game_over)
	game_over.show_game_over()
