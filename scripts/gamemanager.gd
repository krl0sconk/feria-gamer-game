extends Node

const MENU_MUSIC := preload("res://assets/audio/music/musica_menu.wav")

var _menu_music_player: AudioStreamPlayer = null

# Singleton / autoload global. Guarda el run-state que debe sobrevivir a un
# cambio de escena (skin elegido, retorno a Map post-batalla, etc.).

var selectedskin := "idle (1)"

## Posición guardada que se debe re-aplicar cuando cargamos una partida.
var loaded_position: Vector2 = Vector2.ZERO

## Indica si `loaded_position` tiene un valor pendiente por consumir.
var has_loaded_position: bool = false

## Estado de mundo cargado desde un save. Lo consumen sistemas como el
## spawner de bullies al entrar al mapa.
var loaded_world_state: Dictionary = {}

## Indica si `loaded_world_state` tiene datos pendientes por consumir.
var has_loaded_world_state: bool = false

## Estado de mundo de la partida en curso (bullies del pasillo, etc.).
## Sobrevive a recargas de map.tscn dentro de la misma sesión.
var session_world_state: Dictionary = {}

## Escena a la que se debe volver tras la batalla (típicamente Map.tscn).
var return_scene_path: String = ""

## Posición del Player al iniciar la interacción (para re-ubicarlo al volver).
var return_position: Vector2 = Vector2.ZERO

## Id del Interactable que inició la batalla. Vacío = nadie pendiente.
var pending_npc_id: String = ""

## Resultado de la batalla pendiente: "win", "lose" o "" (ninguno).
var pending_dialogue_result: String = ""

## Override opcional del chart que debe usar la siguiente batalla.
var pending_battle_chart_path: String = ""

## Override opcional de música para la siguiente batalla.
var pending_battle_music: AudioStream = null

## Escena de batalla pendiente (path). La consume la pantalla de tutorial o la batalla.
var pending_battle_scene_path: String = ""

## Registro de cinemáticas ya reproducidas (id → true). Persiste en sesión para
## evitar que un on_scene_ready se re-dispare al volver desde una batalla.
var cinematics_played: Dictionary = {}

## Id de la cinemática en reproducción (vacío = ninguna).
var active_cinematic_id: String = ""

var _cinematic_queue: Array[Dictionary] = []
var _current_cinematic_player: CinematicPlayer = null

## Estadísticas de la batalla recién terminada: score, perfects, goods, misses,
## max_combo y chart_path. La WinScreen las consume y luego se limpian.
var pending_battle_stats: Dictionary = {}

## True cuando el jugador aborta batalla/tutorual desde pausa (volver al mapa sin diálogo).
var pending_map_return: bool = false

## Mejor score por chart (chart_path → int). Persiste en disco entre sesiones.
const HIGHSCORES_PATH := "user://highscores.json"
var highscores: Dictionary = {}

## Estado de misiones cargado desde un save.
var _pending_quests_state: Array = []

func _ready() -> void:
	_load_highscores()
	OptionsSettings.apply_saved()
	_menu_music_player = AudioStreamPlayer.new()
	_menu_music_player.name = "MenuMusicPlayer"
	_menu_music_player.stream = MENU_MUSIC
	if AudioServer.get_bus_index(&"Music") != -1:
		_menu_music_player.bus = &"Music"
	_menu_music_player.finished.connect(func() -> void: _menu_music_player.play())
	add_child(_menu_music_player)
	get_tree().node_added.connect(_on_node_added)


func _is_menu_scene(node: Node) -> bool:
	return node.scene_file_path.contains("scenes/menu/")


func _on_node_added(node: Node) -> void:
	if node.get_parent() != get_tree().root:
		return
	if _is_menu_scene(node):
		if not _menu_music_player.playing:
			_menu_music_player.play()
	else:
		_menu_music_player.stop()
		apply_pending_quests_state()  
	var settings := OptionsSettings.load_settings()
	if bool(settings.get("dyslexia_mode", false)):
		OptionsSettings.apply_dyslexia_fonts(node, true)


## Limpia los campos de retorno. Llamado por el root del Map después de
## reanudar el diálogo de resultado.
func clear_pending_dialogue() -> void:
	return_scene_path = ""
	return_position = Vector2.ZERO
	pending_npc_id = ""
	pending_dialogue_result = ""
	pending_battle_chart_path = ""
	pending_battle_music = null
	pending_battle_scene_path = ""
	pending_battle_stats = {}
	pending_map_return = false


## Limpia el estado de batalla pendiente y marca retorno al mapa (abortar desde pausa).
func prepare_abort_from_battle() -> void:
	pending_dialogue_result = ""
	pending_battle_stats = {}
	consume_pending_battle_scene_path()
	consume_pending_battle_chart_path()
	consume_pending_battle_music()
	pending_map_return = true


func set_loaded_position(position: Vector2) -> void:
	loaded_position = position
	has_loaded_position = true


func consume_loaded_position() -> Vector2:
	has_loaded_position = false
	return loaded_position


func set_loaded_world_state(world_state: Dictionary) -> void:
	loaded_world_state = world_state if typeof(world_state) == TYPE_DICTIONARY else {}
	has_loaded_world_state = not loaded_world_state.is_empty()
	if has_loaded_world_state:
		session_world_state = loaded_world_state.duplicate(true)


func consume_loaded_world_state() -> Dictionary:
	has_loaded_world_state = false
	var result := loaded_world_state
	loaded_world_state = {}
	return result


func get_session_world_slice(key: String) -> Dictionary:
	var slice: Variant = session_world_state.get(key, {})
	return slice if typeof(slice) == TYPE_DICTIONARY else {}


func set_session_world_slice(key: String, state: Dictionary) -> void:
	if key.is_empty():
		return
	session_world_state[key] = state if typeof(state) == TYPE_DICTIONARY else {}


func clear_loaded_save_state() -> void:
	loaded_position = Vector2.ZERO
	has_loaded_position = false
	loaded_world_state = {}
	has_loaded_world_state = false
	session_world_state = {}
	_pending_quests_state = []
	cinematics_played = {}
	# Sin esto, el QuestManager (autoload) conserva las quests completadas
	# del slot anterior y el slot nuevo arranca "con todo hecho".
	var qm := get_node_or_null("/root/QuestManager")
	if qm != null and qm.has_method("reset_to_initial_state"):
		qm.call("reset_to_initial_state")
	# Estado de batalla pendiente: si el jugador venía de una batalla y
	# rebotó al menú principal antes de cargar otro slot, estos valores
	# colgaban hasta el siguiente cambio de escena.
	return_scene_path = ""
	return_position = Vector2.ZERO
	pending_npc_id = ""
	pending_dialogue_result = ""
	pending_battle_chart_path = ""
	pending_battle_music = null
	pending_battle_scene_path = ""
	pending_battle_stats = {}
	pending_map_return = false
	active_cinematic_id = ""


func apply_cinematics_played(state: Variant) -> void:
	if typeof(state) != TYPE_DICTIONARY:
		return
	cinematics_played = (state as Dictionary).duplicate()


func set_pending_battle_chart_path(chart_path: String) -> void:
	pending_battle_chart_path = chart_path


func set_pending_battle_music(music: AudioStream) -> void:
	pending_battle_music = music


func set_pending_battle_scene_path(scene_path: String) -> void:
	pending_battle_scene_path = scene_path


func consume_pending_battle_scene_path() -> String:
	var result := pending_battle_scene_path
	pending_battle_scene_path = ""
	return result


func consume_pending_battle_chart_path() -> String:
	var result := pending_battle_chart_path
	pending_battle_chart_path = ""
	return result


func consume_pending_battle_music() -> AudioStream:
	var result: AudioStream = pending_battle_music
	pending_battle_music = null
	return result


## Encola y reproduce una cinemática sin solapar otras. Usado por ScriptedTrigger.
func request_cinematic(path: String, options: Dictionary = {}) -> void:
	if path.is_empty():
		return
	_cinematic_queue.append({"path": path, "options": options})
	_try_play_next_cinematic()


func _try_play_next_cinematic() -> void:
	if _current_cinematic_player != null and is_instance_valid(_current_cinematic_player):
		return
	if _cinematic_queue.is_empty():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return

	var item: Dictionary = _cinematic_queue.pop_front()
	var play_once: bool = bool(item.get("options", {}).get("play_once", true))
	_current_cinematic_player = CinematicPlayer.play_from(str(item.path), scene, play_once)
	if _current_cinematic_player == null:
		_try_play_next_cinematic()
		return

	_current_cinematic_player.cinematic_started.connect(func(id: String) -> void:
		active_cinematic_id = id
	)
	_current_cinematic_player.cinematic_finished.connect(_on_cinematic_queue_finished)


func _on_cinematic_queue_finished(_id: String) -> void:
	active_cinematic_id = ""
	if _current_cinematic_player != null and is_instance_valid(_current_cinematic_player):
		_current_cinematic_player.queue_free()
	_current_cinematic_player = null
	_try_play_next_cinematic()


func set_loaded_quests_state(state: Array) -> void:
	_pending_quests_state = state

func apply_pending_quests_state() -> void:
	if _pending_quests_state.is_empty():
		return
	var qm := get_node_or_null("/root/QuestManager")
	if qm != null and qm.has_method("apply_state"):
		qm.apply_state(_pending_quests_state)
	_pending_quests_state = []


## Compara el score con el highscore guardado del chart. Si mejora, lo guarda
## en disco. Devuelve {previous, current, is_new}.
func record_highscore(chart_path: String, score: int) -> Dictionary:
	if chart_path.is_empty():
		return {"previous": 0, "current": score, "is_new": false}
	var previous: int = int(highscores.get(chart_path, 0))
	var is_new: bool = score > previous
	if is_new:
		highscores[chart_path] = score
		_save_highscores()
	return {"previous": previous, "current": maxi(previous, score), "is_new": is_new}


func _load_highscores() -> void:
	if not FileAccess.file_exists(HIGHSCORES_PATH):
		return
	var text: String = FileAccess.get_file_as_string(HIGHSCORES_PATH)
	if text.is_empty():
		return
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("Gamemanager: highscores.json inválido — se ignora.")
		return
	if typeof(json.data) == TYPE_DICTIONARY:
		highscores = json.data


func _save_highscores() -> void:
	var f := FileAccess.open(HIGHSCORES_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Gamemanager: no se pudo abrir %s para escribir highscores." % HIGHSCORES_PATH)
		return
	f.store_string(JSON.stringify(highscores, "\t"))
	f.close()
