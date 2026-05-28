# Nodo interactuable unificado (NPC u objeto). Sucesor de `quest_object.gd`.
#
# Flujo:
#  1. Player entra al Area2D → `player_in_range = true`.
#  2. Player presiona `Interact` (E) → cargamos el JSON y pedimos al
#     `DialogueRunner` que reproduzca `intro_dialogue_id`.
#  3. Al terminar el diálogo, si `battle_scene` está seteado:
#       - Guardamos en `Gamemanager` el id, la posición de retorno y el path
#         del Map (para que Battle sepa a dónde volver).
#       - `change_scene_to_packed(battle_scene)`.
#     Si está vacío, no pasa nada más (caso "cartel / objeto").
#
# Este nodo no sabe qué dice el JSON ni cómo se renderiza; delega todo al
# DialogueRunner (SRP). La decisión "dialogo → batalla" vive aquí y no en el
# JSON a propósito: el JSON describe qué se dice, la escena decide qué hacer.
@tool
class_name Interactable
extends Area2D

signal interaction_started(id: String)
signal battle_requested(battle_scene: PackedScene, npc_id: String)

const INTERACT_ACTION := "Interact"
const INTERACTION_PATH := "res://assets/audio/sfx/interactionbullie.wav"

## Identificador único dentro del Map. Se usa para reanudar el diálogo tras
## una batalla (Gamemanager.pending_npc_id).
@export var id: String = ""

## Identificador de misión (formato lineal): x.x.x donde la 3ra x=0 indica que
## es la misión principal (no una submisión). Ejemplo: "1.2.0" o "1.2.3".
@export var mission_id: String = ""

## Identificador de misión secundaria (formato: x-x). Ejemplo: "1-3".
@export var secondary_mission_id: String = ""
## Inspector flags: cómo se completa la(s) misión(es) vinculada(s)
@export var complete_mission_on_dialogue: bool = false
@export var complete_mission_on_win: bool = false
## Lista de IDs de misión que se completan por número de interacciones
## Ej: ["1.2.1", "1.2.2"] → completar la primera tras la 1ª charla, la segunda tras la 2ª.
@export var talk_mission_ids: Array[String] = []
## Archivo JSON con los diálogos de este interactuable.
@export_file("*.json") var dialogue_json_path: String = ""

## Diálogo que se reproduce al interactuar por primera vez.
@export var intro_dialogue_id: String = "intro"
## Diálogo alternativo si la misión vinculada ya está completada
@export var intro_dialogue_completed_id: String = ""
## Diálogo que se muestra cuando el enemigo ya fue derrotado (evita re-batalla).
## Si está vacío usa intro_dialogue_completed_id; si ese también está vacío usa "defeated".
@export var defeated_dialogue_id: String = ""

## Diálogo que se reproduce al volver al Map tras GANAR una batalla
## lanzada por este interactuable. Vacío = nada.
@export var win_dialogue_id: String = ""

## Diálogo que se reproduce al volver al Map tras PERDER. Vacío = nada.
@export var lose_dialogue_id: String = ""

## Si está seteado, el intro dispara un cambio a esta escena de batalla al
## terminar. Vacío = solo dialoga y vuelve al control del jugador.
@export var battle_scene: PackedScene = null

## Chart opcional para la batalla asociada. Vacío = usa el default de Battle.
@export_file("*.json") var battle_chart_path: String = ""

## Música opcional para la batalla asociada. Null = usa música por defecto.
@export var battle_music: AudioStream = null

## Si está seteado, tras el diálogo intro se muestra esta pantalla antes de la batalla.
@export_file("*.tscn") var battle_tutorial_screen_path: String = ""

## Si es true, este interactuable se elimina después de mostrar el diálogo
## de victoria. Útil para bullies secundarios de un solo uso.
@export var despawn_on_win: bool = false

## Ruta absoluta al DialogueRunner dentro del árbol de la escena actual.
## Por defecto apunta a un hermano del Map llamado "DialogueRunner".
@export var dialogue_runner_path: NodePath = NodePath("../DialogueRunner")

@export_group("Voz del diálogo")
## Sonido de "blip" estilo 8-bit que se reproduce mientras se revela el
## texto del diálogo, una vez cada N caracteres (configurable en el
## DialogueBox). Pensado para asignar un AudioStream corto (~50-150ms,
## tipo "bip" o "tic") por cada NPC para darle voz distinta a cada uno.
##
## Vacío (null) = silencio durante el typewriter (caso "cartel u objeto").
##
## Tip: usá un AudioStreamRandomizer con varios sonidos + pitch jitter
## para que la voz no sea repetitiva.
@export var dialogue_voice: AudioStream = null

@export_group("Indicador")
## Muestra un ! flotante cuando hay interacción pendiente.
@export var show_indicator: bool = true
## Muestra ! mientras alguna de estas quests esté activa.
@export var indicator_quest_ids: Array[String] = []
## Muestra ! cuando estas quests ya se completaron pero aún no se habló con el NPC.
@export var indicator_after_quests: Array[String] = []

@export_group("Cinemática tras charla")
## Al completar esta quest por charla, reproduce la cinemática indicada.
@export var cinematic_on_talk_quest: String = ""
@export_file("*.json") var cinematic_on_talk_path: String = ""

@export_group("Sprite por misión")
## Animación del Sprite2D mientras la quest indicada no esté completada.
@export var sprite_animation_before_quest: String = ""
## Animación del Sprite2D una vez completada la quest indicada.
@export var sprite_animation_after_quest: String = ""
## Quest que desbloquea `sprite_animation_after_quest` (p. ej. derrotar un bully).
@export var sprite_quest_required: String = ""

@export_group("Diálogo tras misión")
## Tras completar esta quest, la siguiente interacción usa otro JSON/diálogo.
@export var after_quest_required: String = ""
@export_file("*.json") var after_quest_dialogue_path: String = ""
@export var after_quest_dialogue_id: String = ""
## Quest que se completa al terminar el diálogo post-misión.
@export var complete_quest_on_after_dialogue: String = ""

# Nota: la apariencia (sprite / spritesheet / animación) se personaliza por
# instancia vía "Editable Children" sobre el Sprite2D o AnimatedSprite2D hijo.
# Ver comentario en docs del proyecto.

var _player_in_range: bool = false
var _data: DialogueLoader.DialogueData = null
var _runner: DialogueRunner = null
# Flag para rutear el `dialogue_finished` correcto:
#   "intro" → quizá dispara batalla
#   "result" → solo reanuda al jugador
var _current_mode: String = ""
var _interaction_player: AudioStreamPlayer
var _defeat_reported: bool = false
var _talk_count: int = 0
var _acknowledged_after_quests: Dictionary = {}


## --- Save/Load hooks for world state serialization --------------------
func get_save_state_key() -> String:
	if id == null or id.strip_edges() == "":
		return ""
	return "interactable_%s" % str(id)

func serialize_state() -> Dictionary:
	return {
		"talk_count": int(_talk_count),
		"defeat_reported": bool(_defeat_reported),
		"visible": bool(visible),
		"acknowledged_after_quests": _acknowledged_after_quests.duplicate(),
	}

func apply_state(state: Dictionary) -> void:
	if typeof(state) != TYPE_DICTIONARY:
		return
	_talk_count = int(state.get("talk_count", int(_talk_count)))
	_defeat_reported = bool(state.get("defeat_reported", bool(_defeat_reported)))
	if state.has("acknowledged_after_quests") and typeof(state.get("acknowledged_after_quests")) == TYPE_DICTIONARY:
		_acknowledged_after_quests = (state.get("acknowledged_after_quests") as Dictionary).duplicate()
	if state.has("visible"):
		visible = bool(state.get("visible", true))
		if not visible:
			set_process(false)
			monitoring = false
	return
## -----------------------------------------------------------------------


func _ready() -> void:
	_ensure_unique_instance_resources()
	if Engine.is_editor_hint():
		return

	add_to_group("interactables")
	# Register for world save/load so this interactuable can persist talk count
	add_to_group("world_state_serializers")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_interaction_player = _create_interaction_player()
	_runner = get_node_or_null(dialogue_runner_path) as DialogueRunner
	if _runner == null:
		push_warning("Interactable '%s': no se encontró DialogueRunner en '%s'." % [id, str(dialogue_runner_path)])
	else:
		_runner.dialogue_finished.connect(_on_dialogue_finished)
	if not dialogue_json_path.is_empty():
		_data = DialogueLoader.load_json(dialogue_json_path)

	# If a world state was loaded, try to restore our saved state (non-consuming)
	if Gamemanager.has_loaded_world_state:
		var key := get_save_state_key()
		if key != "" and Gamemanager.loaded_world_state.has(key):
			var st: Dictionary = Gamemanager.loaded_world_state.get(key, {})
			if typeof(st) == TYPE_DICTIONARY:
				apply_state(st)

	if QuestManager.has_signal("quest_completed"):
		QuestManager.quest_completed.connect(_on_quest_completed_for_indicator)
	if QuestManager.has_signal("quest_activated"):
		QuestManager.quest_activated.connect(_on_quest_completed_for_indicator)

	_setup_indicator()
	_refresh_sprite_animation()


func _on_quest_completed_for_indicator(_quest_id: String = "") -> void:
	_refresh_indicator()
	_refresh_sprite_animation()


func _ensure_unique_instance_resources() -> void:
	_ensure_unique_sprite_frames()
	_ensure_unique_collision_shapes()


func _ensure_unique_collision_shapes() -> void:
	for shape_node in find_children("*", "CollisionShape2D", false, false):
		var collision := shape_node as CollisionShape2D
		if collision.shape == null:
			continue
		if collision.has_meta("_unique_collision_shape"):
			continue
		collision.shape = collision.shape.duplicate()
		collision.set_meta("_unique_collision_shape", true)


func _ensure_unique_sprite_frames() -> void:
	var sprite := get_node_or_null("Sprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	if sprite.has_meta("_unique_sprite_frames"):
		return
	sprite.sprite_frames = sprite.sprite_frames.duplicate(true)
	sprite.set_meta("_unique_sprite_frames", true)


func should_show_indicator() -> bool:
	if not show_indicator:
		return false
	if _defeat_reported and battle_scene != null:
		return false
	if dialogue_json_path.is_empty() and battle_scene == null and after_quest_dialogue_path.is_empty():
		return false
	if _runner != null and _runner.is_playing():
		return false
	if Gamemanager.active_cinematic_id != "":
		return false
	return _has_pending_interaction()


func _has_pending_interaction() -> bool:
	var qm := get_node_or_null("/root/QuestManager")
	if indicator_quest_ids.size() > 0 or indicator_after_quests.size() > 0:
		if qm == null:
			return false
		for qid in indicator_quest_ids:
			if qm.is_active(str(qid).strip_edges()):
				return true
		for qid in indicator_after_quests:
			var quest_key := str(qid).strip_edges()
			if quest_key != "" and qm.is_completed(quest_key) and not bool(_acknowledged_after_quests.get(quest_key, false)):
				return true
		return false

	if battle_scene != null and not _defeat_reported:
		return true
	if talk_mission_ids.size() > _talk_count:
		return true
	if dialogue_json_path.is_empty() and battle_scene == null:
		return false
	return true


func _refresh_indicator() -> void:
	var indicator := get_node_or_null("InteractionIndicator")
	if indicator != null and indicator.has_method("refresh"):
		indicator.call("refresh")


func _refresh_sprite_animation() -> void:
	var quest_id := str(sprite_quest_required).strip_edges()
	if quest_id == "":
		return
	var before := str(sprite_animation_before_quest).strip_edges()
	var after := str(sprite_animation_after_quest).strip_edges()
	if before == "" and after == "":
		return
	var sprite := get_node_or_null("Sprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	var qm := get_node_or_null("/root/QuestManager")
	var completed := qm != null and qm.is_completed(quest_id)
	var target := after if completed else before
	if target == "" or not sprite.sprite_frames.has_animation(target):
		return
	if sprite.animation != target:
		sprite.animation = target
		sprite.play()


func _setup_indicator() -> void:
	var indicator := get_node_or_null("InteractionIndicator")
	if not show_indicator:
		if indicator != null:
			indicator.visible = false
		return
	if indicator == null:
		var packed: PackedScene = load("res://scenes/cinematic/InteractionIndicator.tscn")
		if packed == null:
			push_warning("Interactable '%s': no se pudo cargar InteractionIndicator.tscn." % id)
			return
		indicator = packed.instantiate()
		indicator.name = "InteractionIndicator"
		add_child(indicator)
	if indicator.has_method("refresh"):
		indicator.call("refresh")


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _player_in_range:
		return
	if _runner != null and _runner.is_playing():
		return
	if Input.is_action_just_pressed(INTERACT_ACTION):
		_start_intro()


## Reanuda el diálogo post-batalla. Llamado desde el root del Map tras leer
## `Gamemanager.pending_dialogue_result`.
func play_result_dialogue(result: String) -> void:
	var dialogue_id := ""
	match result:
		"win":
			dialogue_id = win_dialogue_id
		"lose":
			dialogue_id = lose_dialogue_id
		_:
			return

	# Si el jugador ganó, notificar a cualquier sistema de estado mundial
	# (por ejemplo BullySpawnManager) que este NPC fue derrotado, para que
	# actualicen su estado persistente y ajusten charts/rematch.
	if result == "win" and not _defeat_reported:
		_defeat_reported = true
		for node in get_tree().get_nodes_in_group("world_state_serializers"):
			if node == null:
				continue
			if node.has_method("on_npc_defeated"):
				node.call("on_npc_defeated", id)

		# Notificar al QuestManager sobre la derrota si este interactuable está
		# vinculado a una misión (lineal o secundaria).
		var qm := get_node_or_null("/root/QuestManager")
		if qm != null and qm.has_method("on_enemy_defeated"):
			if mission_id != null and mission_id.strip_edges() != "":
				qm.call("on_enemy_defeated", str(mission_id))
			if secondary_mission_id != null and secondary_mission_id.strip_edges() != "":
				qm.call("on_enemy_defeated", str(secondary_mission_id))

		# Si el inspector indica completar la misión al ganar la batalla,
		# usar `complete_quest` para marcarla como completada inmediatamente.
		if complete_mission_on_win and qm != null and qm.has_method("complete_quest"):
			if mission_id != null and mission_id.strip_edges() != "":
				qm.call("complete_quest", str(mission_id))
			if secondary_mission_id != null and secondary_mission_id.strip_edges() != "":
				qm.call("complete_quest", str(secondary_mission_id))

	if dialogue_id.is_empty() or _data == null or _runner == null:
		return
	_current_mode = "result"

	_runner.play(_data, dialogue_id, dialogue_voice)




func _start_intro() -> void:
	_play_interaction_sfx()
	if _try_start_after_quest_dialogue():
		return
	if _data == null or _runner == null:
		# Fallback: si no hay JSON/Runner pero sí batalla, preservamos el
		# comportamiento del viejo quest_object (ir directo a la batalla).
		if battle_scene != null:
			_queue_battle_transition()
		return
	var chosen_intro := intro_dialogue_id
	# Si el enemigo ya fue derrotado, mostrar diálogo de derrota y nunca re-batallar.
	if _defeat_reported and battle_scene != null:
		var fallback := defeated_dialogue_id
		if fallback.is_empty():
			fallback = intro_dialogue_completed_id
		if fallback.is_empty():
			fallback = "defeated"
		_current_mode = "intro"
		interaction_started.emit(id)
		_runner.play(_data, fallback, dialogue_voice)
		return
	var qm := get_node_or_null("/root/QuestManager")
	if qm != null:
		if mission_id != null and mission_id.strip_edges() != "" and qm.is_completed(mission_id):
			if intro_dialogue_completed_id != "":
				chosen_intro = intro_dialogue_completed_id
		elif secondary_mission_id != null and secondary_mission_id.strip_edges() != "" and qm.is_completed(secondary_mission_id):
			if intro_dialogue_completed_id != "":
				chosen_intro = intro_dialogue_completed_id

	_current_mode = "intro"
	interaction_started.emit(id)
	_runner.play(_data, chosen_intro, dialogue_voice)


func _try_start_after_quest_dialogue() -> bool:
	if after_quest_required.is_empty() or after_quest_dialogue_path.is_empty() or after_quest_dialogue_id.is_empty():
		return false
	if _runner == null:
		return false
	var qm := get_node_or_null("/root/QuestManager")
	if qm == null or not qm.is_completed(after_quest_required):
		return false
	if bool(_acknowledged_after_quests.get(after_quest_required, false)):
		return false

	var after_data := DialogueLoader.load_json(after_quest_dialogue_path)
	if after_data == null:
		push_warning("Interactable '%s': no se pudo cargar after_quest_dialogue_path." % id)
		return false

	_current_mode = "after_quest"
	interaction_started.emit(id)
	_runner.play(after_data, after_quest_dialogue_id, dialogue_voice)
	return true


func _on_dialogue_finished(dialogue_id: String) -> void:
	# Ignorar finales que no correspondan a este interactuable.
	if _current_mode == "":
		return
	var mode := _current_mode
	_current_mode = ""
	# Note: interactuables (especialmente bullies secundarios) no se eliminan
	# automáticamente tras una victoria. El comportamiento de permanecer en
	# el mapa es el esperado; si se desea conservabilidad por diseño, se
	# controla por la propiedad `despawn_on_win`, pero por defecto no se
	# realiza `queue_free` aquí.
	if mode == "after_quest":
		_acknowledged_after_quests[after_quest_required] = true
		var qm_after := get_node_or_null("/root/QuestManager")
		if complete_quest_on_after_dialogue != "" and qm_after != null and qm_after.has_method("complete_quest"):
			qm_after.call("complete_quest", str(complete_quest_on_after_dialogue).strip_edges())
		_refresh_indicator()
		return

	if mode == "intro":
		# Si este interactuable tiene misiones por charla, contabilizamos
		# y marcamos la misión correspondiente cuando aplique.
		var completed_talk_quest := ""
		if talk_mission_ids.size() > 0:
			_talk_count += 1
			var idx := _talk_count - 1
			if idx >= 0 and idx < talk_mission_ids.size():
				var qm := get_node_or_null("/root/QuestManager")
				var qid := str(talk_mission_ids[idx]).strip_edges()
				if qid != "" and qm != null and qm.has_method("complete_quest"):
					qm.call("complete_quest", qid)
					completed_talk_quest = qid
		if not cinematic_on_talk_path.is_empty() and completed_talk_quest == cinematic_on_talk_quest.strip_edges():
			Gamemanager.request_cinematic(cinematic_on_talk_path, {"play_once": true})
		_refresh_indicator()

		# Si el inspector indica que la(s) misión(es) vinculada(s) se deben
		# completar tras el diálogo, notificamos al QuestManager.
		if complete_mission_on_dialogue:
			var qm2 := get_node_or_null("/root/QuestManager")
			if qm2 != null and qm2.has_method("complete_quest"):
				if mission_id != null and mission_id.strip_edges() != "":
					qm2.call("complete_quest", str(mission_id))
				if secondary_mission_id != null and secondary_mission_id.strip_edges() != "":
					qm2.call("complete_quest", str(secondary_mission_id))
		
		if battle_scene != null and not _defeat_reported:
			# Comprobamos que el id terminado sea el de intro (safety — por si el
			# Runner reprodujo otra cosa por encima).
			if dialogue_id == intro_dialogue_id:
				if not battle_tutorial_screen_path.is_empty():
					_queue_tutorial_transition()
				else:
					_queue_battle_transition()


func _prepare_pending_battle() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var return_position := Vector2.ZERO
	if player != null:
		return_position = player.global_position
	Gamemanager.return_scene_path = str(get_tree().current_scene.scene_file_path)
	Gamemanager.return_position = return_position
	Gamemanager.pending_npc_id = id
	Gamemanager.pending_dialogue_result = ""
	Gamemanager.set_pending_battle_chart_path(battle_chart_path)
	Gamemanager.set_pending_battle_music(battle_music)
	if battle_scene != null:
		Gamemanager.set_pending_battle_scene_path(battle_scene.resource_path)


func _queue_battle_transition() -> void:
	_prepare_pending_battle()
	battle_requested.emit(battle_scene, id)
	_refresh_indicator()
	get_tree().change_scene_to_packed(battle_scene)


func _queue_tutorial_transition() -> void:
	_prepare_pending_battle()
	battle_requested.emit(battle_scene, id)
	_refresh_indicator()
	get_tree().change_scene_to_file(battle_tutorial_screen_path)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func _create_interaction_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = "InteractionSfxPlayer"
	player.stream = load(INTERACTION_PATH) as AudioStream
	player.volume_db = -3.3
	if AudioServer.get_bus_index(&"SFX") != -1:
		player.bus = &"SFX"
	add_child(player)
	return player


func _play_interaction_sfx() -> void:
	if _interaction_player != null:
		_interaction_player.stop()
		_interaction_player.play()
