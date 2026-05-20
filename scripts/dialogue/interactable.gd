# Nodo interactuable unificado (NPC u objeto). Sucesor de `quest_object.gd`.
#
# Flujo:
#  1. Player entra al Area2D → `player_in_range = true`.
#  2. Player presiona `Interact` (E) → cargamos el JSON y pedimos al
#     `DialogueRunner` que reproduzca `intro_dialogue_id`.
#  3. Al terminar el diálogo, si `battle_scene_path` está seteado:
#       - Guardamos en `Gamemanager` el id, la posición de retorno y el path
#         del Map (para que Battle sepa a dónde volver).
#       - `change_scene_to_file(battle_scene_path)`.
#     Si está vacío, no pasa nada más (caso "cartel / objeto").
#
# Este nodo no sabe qué dice el JSON ni cómo se renderiza; delega todo al
# DialogueRunner (SRP). La decisión "dialogo → batalla" vive aquí y no en el
# JSON a propósito: el JSON describe qué se dice, la escena decide qué hacer.
class_name Interactable
extends Area2D

signal interaction_started(id: String)
signal battle_requested(battle_scene_path: String, npc_id: String)

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
## Archivo JSON con los diálogos de este interactuable.
@export_file("*.json") var dialogue_json_path: String = ""

## Diálogo que se reproduce al interactuar por primera vez.
@export var intro_dialogue_id: String = "intro"

## Diálogo que se reproduce al volver al Map tras GANAR una batalla
## lanzada por este interactuable. Vacío = nada.
@export var win_dialogue_id: String = ""

## Diálogo que se reproduce al volver al Map tras PERDER. Vacío = nada.
@export var lose_dialogue_id: String = ""

## Si está seteado, el intro dispara un cambio a esta escena de batalla al
## terminar. Vacío = solo dialoga y vuelve al control del jugador.
@export_file("*.tscn") var battle_scene_path: String = ""

## Chart opcional para la batalla asociada. Vacío = usa el default de Battle.
@export_file("*.json") var battle_chart_path: String = ""

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


func _ready() -> void:
	add_to_group("interactables")
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


func _process(_delta: float) -> void:
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
	if dialogue_id.is_empty() or _data == null or _runner == null:
		return
	_current_mode = "result"

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

	_runner.play(_data, dialogue_id, dialogue_voice)




func _start_intro() -> void:
	_play_interaction_sfx()
	if _data == null or _runner == null:
		# Fallback: si no hay JSON/Runner pero sí batalla, preservamos el
		# comportamiento del viejo quest_object (ir directo a la batalla).
		if not battle_scene_path.is_empty():
			_queue_battle_transition()
		return
	_current_mode = "intro"
	interaction_started.emit(id)
	_runner.play(_data, intro_dialogue_id, dialogue_voice)


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
	if mode == "intro" and not battle_scene_path.is_empty():
		# Comprobamos que el id terminado sea el de intro (safety — por si el
		# Runner reprodujo otra cosa por encima).
		if dialogue_id == intro_dialogue_id:
			_queue_battle_transition()


func _queue_battle_transition() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var return_position := Vector2.ZERO
	if player != null:
		return_position = player.global_position
	# Persistimos en Gamemanager para que Battle/WinScreen/LoseScreen sepan
	# qué NPC reanudar al volver.
	Gamemanager.return_scene_path = str(get_tree().current_scene.scene_file_path)
	Gamemanager.return_position = return_position
	Gamemanager.pending_npc_id = id
	Gamemanager.pending_dialogue_result = ""
	Gamemanager.set_pending_battle_chart_path(battle_chart_path)
	battle_requested.emit(battle_scene_path, id)
	get_tree().change_scene_to_file(battle_scene_path)


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
