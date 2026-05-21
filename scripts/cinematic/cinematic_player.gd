# Reproductor de cinemáticas. Lee un JSON con CinematicLoader y ejecuta los
# pasos en secuencia usando el patrón Command: cada tipo de paso está registrado
# en `_commands` como un Callable independiente (el "comando").
#
# Para usarlo en cualquier escena:
#   1. Instancia scenes/cinematic/CinematicPlayer.tscn como hijo de la escena.
#   2. Asigna `cinematic_json_path` en el Inspector.
#   3. El trigger del JSON determina cuándo se activa automáticamente.
#      También puedes llamar play() manualmente con auto_play = false.
#
# Bloqueo de movimiento: usa los pasos "disable_player" / "enable_player" en el
# JSON. Los diálogos internos también bloquean el movimiento automáticamente
# mientras el DialogueRunner embebido esté activo.
class_name CinematicPlayer
extends CanvasLayer

signal cinematic_started(id: String)
signal cinematic_finished(id: String)

## Ruta al JSON de definición de cinemática.
@export_file("*.json") var cinematic_json_path: String = ""
## Si false, llama play() manualmente; el trigger del JSON se ignora.
@export var auto_play: bool = true
## Si true, la cinemática sólo se reproduce una vez por partida (guarda en
## Gamemanager.cinematics_played). Desactívalo para cinemáticas repetibles.
@export var play_once: bool = true

var _black_screen: ColorRect = null
var _runner: DialogueRunner  = null

var _data: CinematicLoader.CinematicData = null
var _is_playing: bool = false
## Tabla de comandos — patrón Command. Clave: tipo de paso; valor: Callable.
var _commands: Dictionary = {}


func _ready() -> void:
	_commands = {
		"fade_to_black":   _cmd_fade_to_black,
		"fade_from_black": _cmd_fade_from_black,
		"wait":            _cmd_wait,
		"dialogue":        _cmd_dialogue,
		"move_node":       _cmd_move_node,
		"show_node":       _cmd_show_node,
		"hide_node":       _cmd_hide_node,
		"disable_player":  _cmd_disable_player,
		"enable_player":   _cmd_enable_player,
		"change_scene":    _cmd_change_scene,
	}

	_setup_black_screen()
	_setup_runner()

	if cinematic_json_path.is_empty():
		return
	_data = CinematicLoader.load_json(cinematic_json_path)
	if auto_play:
		call_deferred("_wire_trigger")


func _setup_black_screen() -> void:
	# Reutilizar si ya existe como hijo (p.ej. instanciado desde .tscn).
	_black_screen = get_node_or_null("BlackScreen") as ColorRect
	if _black_screen == null:
		_black_screen = ColorRect.new()
		_black_screen.name = "BlackScreen"
		add_child(_black_screen)
	_black_screen.color = Color(0.0, 0.0, 0.0, 0.0)
	_black_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(func() -> void:
		_black_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	)


func _setup_runner() -> void:
	# Reutilizar si ya existe como hijo (p.ej. instanciado desde .tscn).
	_runner = get_node_or_null("DialogueRunner") as DialogueRunner
	if _runner == null:
		var packed: PackedScene = load("res://scenes/dialogue/dialogue_runner.tscn")
		if packed == null:
			push_error("CinematicPlayer: no se pudo cargar dialogue_runner.tscn")
			return
		_runner = packed.instantiate() as DialogueRunner
		_runner.name = "DialogueRunner"
		_runner.layer = 21
		add_child(_runner)


func _wire_trigger() -> void:
	if _data == null:
		return
	var trigger_type: String = str(_data.trigger.get("type", "on_scene_ready"))
	match trigger_type:
		"on_scene_ready":
			# Esperar al menos un frame para que todos los nodos estén listos.
			await get_tree().process_frame
			var delay: float = float(_data.trigger.get("delay", 0.0))
			if delay > 0.0:
				await get_tree().create_timer(delay).timeout
			play()

		"on_quest_completed":
			var quest_id: String = str(_data.trigger.get("quest_id", ""))
			if quest_id.is_empty():
				push_warning("CinematicPlayer: trigger on_quest_completed sin quest_id en '%s'." % cinematic_json_path)
				return
			QuestManager.quest_completed.connect(func(qid: String) -> void:
				if qid == quest_id:
					await _wait_for_active_dialogues()
					play()
			)

		"on_area_entered":
			var area := get_node_or_null("TriggerArea") as Area2D
			if area == null:
				push_warning("CinematicPlayer: trigger on_area_entered pero no hay hijo Area2D llamado 'TriggerArea'.")
				return
			var required_quest: String = str(_data.trigger.get("requires_quest", ""))
			area.body_entered.connect(func(body: Node) -> void:
				if not body.is_in_group("player"):
					return
				if not required_quest.is_empty() and not QuestManager.is_completed(required_quest):
					return
				play()
			)

		_:
			push_warning("CinematicPlayer: tipo de trigger desconocido '%s'." % trigger_type)


## Inicia la reproducción de la cinemática. Si play_once está activo y ya se
## reprodujo, no hace nada. Se puede llamar manualmente cuando auto_play=false.
func play() -> void:
	if _data == null or _is_playing:
		return
	if play_once and Gamemanager.cinematics_played.get(_data.id, false):
		return

	_is_playing = true
	if play_once and not _data.id.is_empty():
		Gamemanager.cinematics_played[_data.id] = true

	cinematic_started.emit(_data.id)

	for step: CinematicLoader.CinematicStep in _data.steps:
		if not _is_playing:
			break
		await _execute_step(step)

	_is_playing = false
	cinematic_finished.emit(_data.id)


## Detiene la cinemática en curso (útil para botones de skip).
func stop() -> void:
	_is_playing = false
	_black_screen.color.a = 0.0


# Espera un frame para que cualquier diálogo que se esté iniciando tenga
# tiempo de arrancar, y luego aguarda a que termine antes de reproducir la
# cinemática. Evita solapamiento entre el diálogo de resultado de batalla y
# el diálogo de cinemática on_quest_completed.
func _wait_for_active_dialogues() -> void:
	await get_tree().process_frame
	if get_tree().current_scene == null:
		return
	var runners := get_tree().current_scene.find_children("*", "DialogueRunner", true, false)
	for r in runners:
		if r == _runner:
			continue
		if r.has_method("is_playing") and r.is_playing():
			await r.dialogue_finished


func _execute_step(step: CinematicLoader.CinematicStep) -> void:
	if _commands.has(step.type):
		await _commands[step.type].call(step.params)
	else:
		push_warning("CinematicPlayer: tipo de paso desconocido '%s'." % step.type)


# ── Implementación de comandos ───────────────────────────────────────────────

func _cmd_fade_to_black(params: Dictionary) -> void:
	var duration: float = float(params.get("duration", 0.5))
	var tween := create_tween()
	tween.tween_property(_black_screen, "color:a", 1.0, duration)
	await tween.finished


func _cmd_fade_from_black(params: Dictionary) -> void:
	var duration: float = float(params.get("duration", 0.5))
	var tween := create_tween()
	tween.tween_property(_black_screen, "color:a", 0.0, duration)
	await tween.finished


func _cmd_wait(params: Dictionary) -> void:
	var seconds: float = float(params.get("seconds", 1.0))
	await get_tree().create_timer(seconds).timeout


func _cmd_dialogue(params: Dictionary) -> void:
	var path: String        = str(params.get("path", ""))
	var dialogue_id: String = str(params.get("id", ""))
	if path.is_empty() or dialogue_id.is_empty():
		push_warning("CinematicPlayer: paso 'dialogue' sin 'path' o 'id'.")
		return
	if _runner == null:
		push_error("CinematicPlayer: DialogueRunner no encontrado ($DialogueRunner).")
		return
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("disable_movement"):
		player.disable_movement()
	var data := DialogueLoader.load_json(path)
	_runner.play(data, dialogue_id)
	await _runner.dialogue_finished
	if player != null and player.has_method("enable_movement"):
		player.enable_movement()


func _cmd_move_node(params: Dictionary) -> void:
	var node_path: String = str(params.get("node", ""))
	var to: Array         = params.get("to", [0.0, 0.0])
	var duration: float   = float(params.get("duration", 1.0))
	var target := get_tree().current_scene.get_node_or_null(node_path) as Node2D
	if target == null:
		push_warning("CinematicPlayer: move_node — nodo '%s' no encontrado." % node_path)
		return
	var tween := create_tween()
	tween.tween_property(target, "position", Vector2(float(to[0]), float(to[1])), duration)
	await tween.finished


func _cmd_show_node(params: Dictionary) -> void:
	var node_path: String = str(params.get("node", ""))
	var target := get_tree().current_scene.get_node_or_null(node_path)
	if target != null:
		target.visible = true


func _cmd_hide_node(params: Dictionary) -> void:
	var node_path: String = str(params.get("node", ""))
	var target := get_tree().current_scene.get_node_or_null(node_path)
	if target != null:
		target.visible = false


func _cmd_disable_player(_params: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("disable_movement"):
		player.disable_movement()


func _cmd_enable_player(_params: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("enable_movement"):
		player.enable_movement()


func _cmd_change_scene(params: Dictionary) -> void:
	var path: String = str(params.get("path", ""))
	if path.is_empty():
		push_warning("CinematicPlayer: change_scene sin 'path'.")
		return
	get_tree().change_scene_to_file(path)
