extends Area2D
# Projetil disparado pelo dragao_chefe.
# Voa em linha reta na direcao indicada e causa 1 de dano ao player.

const SPEED := 130.0
const LIFETIME := 4.0  # segundos antes de sumir caso nao atinja nada

@onready var anim := $anim as AnimatedSprite2D
@onready var lifetime_timer := $lifetime_timer as Timer

var direction := -1  # -1 = esquerda, 1 = direita


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	lifetime_timer.timeout.connect(queue_free)
	lifetime_timer.start(LIFETIME)
	anim.play("fly")


func set_direction(d: int) -> void:
	direction = d
	# Espelha o sprite caso esteja indo para o outro lado
	anim.flip_h = (direction == 1)


func _physics_process(delta: float) -> void:
	global_position.x += direction * SPEED * delta


func _on_body_entered(body: Node2D) -> void:
	if body.name == "player":
		var knockback := Vector2(direction * 150.0, -100.0)
		if body.has_method("take_damage"):
			body.take_damage(knockback)
	queue_free()
