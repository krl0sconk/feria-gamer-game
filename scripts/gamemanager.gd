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

## Registro de cinemáticas ya reproducidas (id → true). Persiste en sesión para
## evitar que un on_scene_ready se re-dispare al volver desde una batalla.
var cinematics_played: Dictionary = {}


func _ready() -> void:
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


func set_loaded_position(position: Vector2) -> void:
	loaded_position = position
	has_loaded_position = true


func consume_loaded_position() -> Vector2:
	has_loaded_position = false
	return loaded_position


func set_loaded_world_state(world_state: Dictionary) -> void:
	loaded_world_state = world_state if typeof(world_state) == TYPE_DICTIONARY else {}
	has_loaded_world_state = not loaded_world_state.is_empty()


func consume_loaded_world_state() -> Dictionary:
	has_loaded_world_state = false
	var result := loaded_world_state
	loaded_world_state = {}
	return result


func clear_loaded_save_state() -> void:
	loaded_position = Vector2.ZERO
	has_loaded_position = false
	loaded_world_state = {}
	has_loaded_world_state = false


func set_pending_battle_chart_path(chart_path: String) -> void:
	pending_battle_chart_path = chart_path


func set_pending_battle_music(music: AudioStream) -> void:
	pending_battle_music = music


func consume_pending_battle_chart_path() -> String:
	var result := pending_battle_chart_path
	pending_battle_chart_path = ""
	return result


func consume_pending_battle_music() -> AudioStream:
	var result: AudioStream = pending_battle_music
	pending_battle_music = null
	return result
