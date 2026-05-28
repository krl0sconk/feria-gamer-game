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


## Format: "NodePath|quest_id|MarkerPath|optional_cinematic_id"
## Repositions the node when quest is done. If cinematic_id is set, skips until
## that cinematic has already played (so the outro walk is visible the first time).
@export var reposition_when_quest_done: Array[String] = []

func _ready() -> void:
	_wire_dialogue_to_player()
	_resume_post_battle_dialogue_deferred()
	_setup_bg_music()
	call_deferred("_restore_hallway_encounter_state")
	call_deferred("_apply_quest_repositions")


func _setup_bg_music() -> void:
	for node in find_children("*", "AudioStreamPlayer", true, false):
		var player := node as AudioStreamPlayer
		if not player.autoplay:
			continue
		if AudioServer.get_bus_index(&"Music") != -1:
			player.bus = &"Music"
		if not player.finished.is_connected(player.play):
			player.finished.connect(player.play)



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
	if Gamemanager.pending_map_return:
		Gamemanager.pending_map_return = false
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and Gamemanager.return_position != Vector2.ZERO:
			player.global_position = Gamemanager.return_position
		return

	var result: String = Gamemanager.pending_dialogue_result
	var npc_id: String = Gamemanager.pending_npc_id
	if result.is_empty() or npc_id.is_empty():
		return

	_restore_hallway_encounter_state()

	# Re-ubicamos al Player en su posición previa a la batalla.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		if result == "lose" and npc_id == "hallway_bully":
			var rematch := get_node_or_null("Markers/HallwayRematchPos") as Node2D
			if rematch != null:
				player.global_position = rematch.global_position
			elif Gamemanager.return_position != Vector2.ZERO:
				player.global_position = Gamemanager.return_position
		elif Gamemanager.return_position != Vector2.ZERO:
			player.global_position = Gamemanager.return_position

	var target := _find_interactable_by_id(npc_id)
	if target == null:
		Gamemanager.clear_pending_dialogue()
		return
	target.play_result_dialogue(result)
	# Limpiamos antes de que el jugador pueda volver a interactuar — así no
	# re-disparamos el resultado si recarga la escena.
	Gamemanager.clear_pending_dialogue()


func _apply_quest_repositions() -> void:
	for entry in reposition_when_quest_done:
		var parts := str(entry).split("|")
		if parts.size() < 3:
			continue
		var node_path := parts[0].strip_edges()
		var quest_id := parts[1].strip_edges()
		var marker_path := parts[2].strip_edges()
		var cinematic_id := parts[3].strip_edges() if parts.size() > 3 else ""
		if not QuestManager.is_completed(quest_id):
			continue
		if not cinematic_id.is_empty() and not Gamemanager.cinematics_played.get(cinematic_id, false):
			continue
		var target := get_node_or_null(node_path) as Node2D
		var marker := get_node_or_null(marker_path) as Node2D
		if target == null or marker == null:
			continue
		target.global_position = marker.global_position
		if target is Area2D:
			var area := target as Area2D
			area.monitoring = false
			area.monitorable = false
		var indicator := target.get_node_or_null("InteractionIndicator")
		if indicator != null:
			indicator.visible = false


func _find_interactable_by_id(npc_id: String) -> Interactable:
	for node in get_tree().get_nodes_in_group("interactables"):
		if node is Interactable and (node as Interactable).id == npc_id:
			return node
	return null


## Tras la intro del pasillo, los hermanos deben quedarse en su posición de
## bloqueo hasta ganar (3.1.1). Sin esto, al volver de una batalla reaparecen
## al este de la barrera y el jugador no puede reintentar.
func _restore_hallway_encounter_state() -> void:
	if QuestManager.is_completed("3.1.1"):
		return
	if not Gamemanager.cinematics_played.get("hallway_bully_intro", false):
		return
	var stop1 := get_node_or_null("Markers/BullyStopPos") as Node2D
	var stop2 := get_node_or_null("Markers/BullyStopPos2") as Node2D
	var bully1 := get_node_or_null("Bullys/HallwayBully") as Node2D
	var bully2 := get_node_or_null("Bullys/HallwayBully2") as Node2D
	if bully1 != null and stop1 != null:
		bully1.global_position = stop1.global_position
	if bully2 != null and stop2 != null:
		bully2.global_position = stop2.global_position
