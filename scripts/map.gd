# Controlador del Map (escena top-down). Se encarga de:
#   1. Conectar DialogueRunner → Player (bloqueo de movimiento).
#   2. Reanudar, al volver de una batalla, el diálogo de resultado del NPC
#      que la inició (lo busca en el grupo "interactables" por id).
#
# SRP: solo pega cables entre los nodos de la escena. No sabe de JSON, ni
# de batallas, ni de HUD.
extends Node2D

@export var dialogue_runner_path: NodePath = NodePath("DialogueRunner")

@onready var _runner: DialogueRunner = get_node_or_null(dialogue_runner_path) as DialogueRunner


func _ready() -> void:
	_wire_dialogue_to_player()
	_resume_post_battle_dialogue_deferred()



func _wire_dialogue_to_player() -> void:
	if _runner == null:
		push_warning("Map: no hay DialogueRunner en '%s'." % str(dialogue_runner_path))
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		# El Player puede no estar en el grupo todavía si aún no corrió su
		# _ready; buscar por nombre como fallback.
		player = get_node_or_null("Player")
	if player == null:
		return
	# Las señales del Runner llevan `dialogue_id: String`; los métodos del
	# Player no lo usan → `unbind(1)` absorbe ese argumento.
	var on_start := Callable(player, "disable_movement").unbind(1)
	var on_end := Callable(player, "enable_movement").unbind(1)
	if not _runner.dialogue_started.is_connected(on_start):
		_runner.dialogue_started.connect(on_start)
	if not _runner.dialogue_finished.is_connected(on_end):
		_runner.dialogue_finished.connect(on_end)



func _resume_post_battle_dialogue_deferred() -> void:
	# Difierido para que todos los _ready hijos (Interactables, Player,
	# DialogueRunner/Box) hayan corrido antes de pedir el replay.
	call_deferred("_resume_post_battle_dialogue")


func _resume_post_battle_dialogue() -> void:
	var result: String = Gamemanager.pending_dialogue_result
	var npc_id: String = Gamemanager.pending_npc_id
	if result.is_empty() or npc_id.is_empty():
		return

	# Re-ubicamos al Player en su posición previa a la batalla.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and Gamemanager.return_position != Vector2.ZERO:
		player.global_position = Gamemanager.return_position

	var target := _find_interactable_by_id(npc_id)
	if target == null:
		Gamemanager.clear_pending_dialogue()
		return
	target.play_result_dialogue(result)
	# Limpiamos antes de que el jugador pueda volver a interactuar — así no
	# re-disparamos el resultado si recarga la escena.
	Gamemanager.clear_pending_dialogue()


func _find_interactable_by_id(npc_id: String) -> Interactable:
	for node in get_tree().get_nodes_in_group("interactables"):
		if node is Interactable and (node as Interactable).id == npc_id:
			return node
	return null
