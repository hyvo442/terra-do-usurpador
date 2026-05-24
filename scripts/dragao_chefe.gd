extends CharacterBody2D
# Inimigo misto (hibrido) - alterna ataque a distancia e perseguicao corpo-a-corpo.
#
# Loop de IA:
#   IDLE -> (player detectado) -> RANGED_ATTACK
#   RANGED_ATTACK -> (fim da animacao) dispara projetil + inicia cooldown 5s -> CHASE
#   CHASE -> persegue o player com a animacao "run"
#     -> se chegar perto e melee_cooldown ok: MELEE_ATTACK
#     -> se ranged_cooldown zerar: RETREAT (moonwalk)
#   MELEE_ATTACK -> (fim da animacao) volta para CHASE com melee_cooldown=2s
#   RETREAT -> recua curta distancia mantendo a cara virada pro player -> RANGED_ATTACK
#
# Notas:
# - 10 pontos de vida (MAX_HP).
# - Causa dano por contato (esta no grupo "contact_damage"). O player.gd ja trata isso.
# - Pode ser morto pisando na cabeca (hitbox).
# - Quando morre, toca a animacao "hurt" e congela no ultimo frame no cenario.
# - Emite "hp_changed" sempre que perde HP (para atualizar HUD do chefe).
# - Emite "died" depois de 2 segundos da morte (delay solicitado, usado pelo
#   world_03 para liberar a entrada no trono apenas apos o intervalo).


# Sinal emitido sempre que o HP muda. Carrega o HP atual e o maximo (util
# para HUDs/barras de vida).
signal hp_changed(current_hp: int, max_hp: int)

# Sinal emitido 2 segundos depois do inimigo morrer. O delay eh um requisito
# de design - o world_03 so libera a transicao para a tela de vitoria depois
# desse intervalo.
signal died

const SPEED := 60.0            # ajustado para o tamanho 1.5x (era 60)
const RETREAT_SPEED := 50.0    # ajustado para o tamanho 1.5x (era 40)
# A colisao do corpo do dragao_chefe eh muito larga (~252px), entao a distancia
# minima possivel entre os centros do player e do inimigo eh aproximadamente
# 147px (half_body_enemy + half_body_player). O valor antigo de 39 nunca era
# atingido na pratica - o player batia no corpo do inimigo antes do dist_x
# ficar pequeno o suficiente, e o ataque_perto nunca disparava.
const MELEE_RANGE := 180.0
const MELEE_COOLDOWN := 3.0
const RANGED_COOLDOWN := 9.0
const RETREAT_DURATION := 4.0
const MAX_HP := 10
# Frames da animacao "ataque_perto" em que o golpe realmente machuca.
const MELEE_DAMAGE_FRAMES := [3, 4]

enum State { IDLE, RANGED_ATTACK, CHASE, MELEE_ATTACK, RETREAT, HURT, DEAD }

@export var projectile_scene: PackedScene

@onready var anim := $anim as AnimatedSprite2D
@onready var detection_area := $detection_area as Area2D
@onready var projectile_spawn := $projectile_spawn as Marker2D
@onready var body_shape := $CollisionShape2D as CollisionShape2D
@onready var hitbox := $hitbox as Area2D                          # area do stomp/bounce
@onready var hitbox_shape := $hitbox/colision2 as CollisionShape2D
@onready var detection_shape := $detection_area/CollisionShape2D as CollisionShape2D
@onready var ataque_perto_hitbox := $ataque_perto_hitbox as Area2D

var state: int = State.IDLE
var player: Node2D = null
var direction := 1            # 1 = direita, -1 = esquerda
var hp: int = MAX_HP
var _ranged_cooldown := 0.0    # tempo restante ate poder atirar de novo
var _melee_cooldown := 0.0     # tempo restante ate poder atacar de perto de novo
var _retreat_timer := 0.0      # tempo restante de moonwalk
var _hit_this_melee_attack := false  # cada ataque_perto so machuca uma vez


func _ready() -> void:
	# Grupo "contact_damage" - sinaliza pro player.gd que este inimigo
	# machuca por contato (a cena tambem ja declara o grupo, isso aqui eh
	# defensivo caso o nodo seja instanciado sem o group preservado).
	add_to_group("contact_damage")
	detection_area.body_entered.connect(_on_player_detected)
	detection_area.body_exited.connect(_on_player_lost)
	anim.animation_finished.connect(_on_anim_finished)
	anim.play("idle")
	# Avisa HUDs ligados no sinal qual eh o HP inicial (no proximo frame, para
	# que quem se conectar no _ready do mundo ja receba esse primeiro emit).
	call_deferred("emit_signal", "hp_changed", hp, MAX_HP)


func _physics_process(delta: float) -> void:
	# Estado morto: so cai pela gravidade ate o chao e fica ali.
	if state == State.DEAD:
		if not is_on_floor():
			velocity.y += get_gravity().y * delta
		velocity.x = 0
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	if _ranged_cooldown > 0.0:
		_ranged_cooldown -= delta
	if _melee_cooldown > 0.0:
		_melee_cooldown -= delta

	# Mantem sempre virado para o player (inclusive durante moonwalk)
	if state != State.IDLE and state != State.HURT and is_instance_valid(player):
		_face_player()

	match state:
		State.IDLE:
			velocity.x = 0
			_safe_play("idle")
			if is_instance_valid(player):
				_enter_ranged_attack()

		State.RANGED_ATTACK:
			# Para. A animacao manda no resto - quando termina, dispara o projetil.
			velocity.x = 0

		State.CHASE:
			if not is_instance_valid(player):
				state = State.IDLE
				velocity.x = 0
			else:
				var dist_x: float = abs(player.global_position.x - global_position.x)
				if dist_x <= MELEE_RANGE and _melee_cooldown <= 0.0:
					_enter_melee_attack()
				elif _ranged_cooldown <= 0.0:
					_enter_retreat()
				else:
					velocity.x = direction * SPEED
					_safe_play("run")

		State.MELEE_ATTACK:
			velocity.x = 0
			# Durante os frames de impacto do golpe, verifica se a hitbox
			# do ataque encostou no player e causa dano.
			if anim.animation == "ataque_perto" and anim.frame in MELEE_DAMAGE_FRAMES:
				_try_melee_damage()

		State.RETREAT:
			_retreat_timer -= delta
			# Moonwalk: anda para o lado oposto da direcao que esta encarando.
			velocity.x = -direction * RETREAT_SPEED
			_safe_play("run")
			if _retreat_timer <= 0.0:
				_enter_ranged_attack()

		State.HURT:
			velocity.x = 0

	move_and_slide()


# Vira o sprite para encarar o player e reposiciona o spawn do projetil.
func _face_player() -> void:
	if not is_instance_valid(player):
		return
	direction = 1 if player.global_position.x > global_position.x else -1
	# Sprite default do arqueiro olha pra esquerda; espelha quando vai pra direita.
	anim.flip_h = (direction == 1)
	projectile_spawn.position.x = abs(projectile_spawn.position.x) * direction
	ataque_perto_hitbox.position.x = abs(ataque_perto_hitbox.position.x) * direction
	# A forma de colisao do ataque_perto_hitbox foi posicionada no editor com
	# um offset negativo em relacao ao pai, entao tambem precisamos espelhar
	# essa posicao para o hitbox aparecer na frente do arqueiro - e nao sempre
	# atras dele (que era o motivo do ataque nunca conectar mesmo quando era
	# disparado).
	var inner_shape := ataque_perto_hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if inner_shape:
		inner_shape.position.x = abs(inner_shape.position.x) * direction


func _enter_ranged_attack() -> void:
	state = State.RANGED_ATTACK
	velocity.x = 0
	_face_player()
	_safe_play("ataque_distancia")


func _enter_melee_attack() -> void:
	state = State.MELEE_ATTACK
	velocity.x = 0
	_melee_cooldown = MELEE_COOLDOWN
	_hit_this_melee_attack = false
	_safe_play("ataque_perto")


# Aplica dano no player se ele estiver sobreposto ao ataque_perto_hitbox
# durante a janela de impacto. Cada golpe so machuca uma vez.
func _try_melee_damage() -> void:
	if _hit_this_melee_attack:
		return
	for body in ataque_perto_hitbox.get_overlapping_bodies():
		if body.name == "player" and body.has_method("take_damage"):
			var knockback := Vector2(direction * 180.0, -150.0)
			body.take_damage(knockback)
			_hit_this_melee_attack = true
			break


func _enter_retreat() -> void:
	state = State.RETREAT
	_retreat_timer = RETREAT_DURATION


# Cria o projetil e o lanca na direcao atual.
func _spawn_projectile() -> void:
	if projectile_scene == null:
		push_warning("dragao_chefe: projectile_scene nao definido no Inspector")
		return
	var p := projectile_scene.instantiate()
	get_parent().add_child(p)
	p.global_position = projectile_spawn.global_position
	if p.has_method("set_direction"):
		p.set_direction(direction)


# ---------------- Sinais ----------------

func _on_player_detected(body: Node2D) -> void:
	if body.name == "player":
		player = body
		if state == State.IDLE:
			_enter_ranged_attack()


func _on_player_lost(body: Node2D) -> void:
	if body == player:
		player = null


func _on_anim_finished() -> void:
	match anim.animation:
		"ataque_distancia":
			# Dispara o projetil exatamente quando o ataque termina.
			_spawn_projectile()
			_ranged_cooldown = RANGED_COOLDOWN
			if is_instance_valid(player):
				state = State.CHASE
			else:
				state = State.IDLE

		"ataque_perto":
			if is_instance_valid(player):
				state = State.CHASE
			else:
				state = State.IDLE

		"hurt":
			# Quando o inimigo morre, a hurt termina e ele fica no ultimo
			# frame por estar com loop=false. So entramos em DEAD aqui.
			if hp <= 0:
				_enter_dead()


# ---------------- Dano / morte ----------------

# Chamado pela hitbox.tscn quando o player pula em cima.
func on_hit() -> void:
	if state == State.DEAD or state == State.HURT:
		return
	hp -= 1
	hp_changed.emit(hp, MAX_HP)
	if hp <= 0:
		state = State.HURT
		velocity = Vector2.ZERO
		# Desativa hitboxes e dano por contato durante o hurt: player nao toma
		# dano encostando no arqueiro que esta morrendo nem da bounce na cabeca dele.
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
		ataque_perto_hitbox.set_deferred("monitoring", false)
		ataque_perto_hitbox.set_deferred("monitorable", false)
		remove_from_group("contact_damage")
		_safe_play("hurt")
	# Para HP > 0, mantem o estado atual (segue no loop normalmente).


func _enter_dead() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	# Desliga toda a interacao para o player poder passar por cima.
	collision_layer = 0
	hitbox_shape.set_deferred("disabled", true)
	detection_shape.set_deferred("disabled", true)
	# Garante que a anim hurt ja esta no ultimo frame (loop=false faz isso
	# automaticamente, mas pausamos por seguranca).
	anim.pause()
	# Aguarda 2 segundos antes de avisar que o inimigo "morreu de verdade"
	# (intervalo de design). Quem ouve o sinal "died" - tipo o world_03 -
	# so libera a area do trono apos esse delay.
	get_tree().create_timer(2.0).timeout.connect(_emit_died)


func _emit_died() -> void:
	died.emit()


# ---------------- Util ----------------

func _safe_play(anim_name: StringName) -> void:
	if anim.animation != anim_name:
		anim.play(anim_name)
