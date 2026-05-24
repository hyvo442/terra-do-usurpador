extends Area2D
# Area que detecta o player e troca de cena via SceneManager.
# Configure no Inspector o campo "Target Scene" arrastando a cena de destino.

@export_file("*.tscn") var target_scene: String = ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if target_scene == "":
		push_warning("area_transition em %s sem target_scene definido" % name)
		return
	if body.name == "player":
		SceneManager.change_scene(target_scene)
