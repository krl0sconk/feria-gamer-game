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

const TargetResolver = preload("res://scripts/cinematic/cinematic_target_resolver.gd")
const CinematicActorHelper = preload("res://scripts/cinematic/cinematic_actor.gd")
const ScriptedBarrierClass = preload("res://scripts/cinematic/scripted_barrier.gd")
const FollowerClass = preload("res://scripts/cinematic/follower.gd")
const CinematicCameraClass = preload("res://scripts/cinematic/cinematic_camera.gd")

signal cinematic_started(id: String)
signal cinematic_finished(id: String)
signal cinematic_skipped(id: String)

## Ruta al JSON de definición de cinemática.
@export_file("*.json") var cinematic_json_path: String = ""
## Si false, llama play() manualmente; el trigger del JSON se ignora.
@export var auto_play: bool = true
## Si true, la cinemática sólo se reproduce una vez por partida (guarda en
## Gamemanager.cinematics_played). Desactívalo para cinemáticas repetibles.
@export var play_once: bool = true
## Si true, la pantalla arranca en negro desde el primer frame — evita el
## flash del mapa en cinemáticas con delay 0 que empiezan con fade_from_black.
@export var start_black: bool = false
## Si true, el jugador puede saltar la cinemática con Interact (E).
@export var allow_skip: bool = true

var _black_screen: ColorRect = null
var _letterbox_top: ColorRect = null
var _letterbox_bottom: ColorRect = null
var _runner: DialogueRunner  = null
var _sfx_player: AudioStreamPlayer = null

var _data: CinematicLoader.CinematicData = null
var _is_playing: bool = false
var _was_skipped: bool = false
var _running_tweens: Array[Tween] = []
## Tabla de comandos — patrón Command. Clave: tipo de paso; valor: Callable.
var _commands: Dictionary = {}


func _ready() -> void:
	_commands = {
		"fade_to_black":   _cmd_fade_to_black,
		"fade_from_black": _cmd_fade_from_black,
		"wait":            _cmd_wait,
		"dialogue":        _cmd_dialogue,
		"move_node":       _cmd_move_node,
		"walk_to":         _cmd_walk_to,
		"walk_path":       _cmd_walk_path,
		"face_direction":  _cmd_face_direction,
		"play_animation":  _cmd_play_animation,
		"set_collision":   _cmd_set_collision,
		"wait_for_player_near": _cmd_wait_for_player_near,
		"enable_barrier":  _cmd_enable_barrier,
		"disable_barrier": _cmd_disable_barrier,
		"start_battle":    _cmd_start_battle,
		"follower_lead":   _cmd_follower_lead,
		"follower_follow": _cmd_follower_follow,
		"follower_stop":   _cmd_follower_stop,
		"camera_focus":    _cmd_camera_focus,
		"camera_release":  _cmd_camera_release,
		"shake_camera":    _cmd_shake_camera,
		"letterbox":       _cmd_letterbox,
		"play_sfx":        _cmd_play_sfx,
		"show_node":       _cmd_show_node,
		"hide_node":       _cmd_hide_node,
		"disable_player":  _cmd_disable_player,
		"enable_player":   _cmd_enable_player,
		"change_scene":    _cmd_change_scene,
	}

	_setup_black_screen()
	_setup_letterbox()
	_setup_runner()
	_setup_sfx_player()
	set_process_unhandled_input(true)

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
	_black_screen.color = Color(0.0, 0.0, 0.0, 1.0 if start_black else 0.0)
	_black_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(func() -> void:
		_black_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	)


func _setup_letterbox() -> void:
	_letterbox_top = get_node_or_null("LetterboxTop") as ColorRect
	_letterbox_bottom = get_node_or_null("LetterboxBottom") as ColorRect
	if _letterbox_top == null:
		_letterbox_top = ColorRect.new()
		_letterbox_top.name = "LetterboxTop"
		add_child(_letterbox_top)
	if _letterbox_bottom == null:
		_letterbox_bottom = ColorRect.new()
		_letterbox_bottom.name = "LetterboxBottom"
		add_child(_letterbox_bottom)

	for bar in [_letterbox_top, _letterbox_bottom]:
		bar.color = Color(0.0, 0.0, 0.0, 1.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.visible = true

	_layout_letterbox(0.0)
	get_viewport().size_changed.connect(_on_viewport_resized_for_letterbox)


func _on_viewport_resized_for_letterbox() -> void:
	var top_h: float = _letterbox_top.size.y if _letterbox_top != null else 0.0
	_layout_letterbox(top_h)


func _layout_letterbox(bar_height: float) -> void:
	if _letterbox_top == null or _letterbox_bottom == null:
		return
	_letterbox_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_letterbox_top.offset_left = 0.0
	_letterbox_top.offset_top = 0.0
	_letterbox_top.offset_right = 0.0
	_letterbox_top.offset_bottom = bar_height

	_letterbox_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_letterbox_bottom.offset_left = 0.0
	_letterbox_bottom.offset_top = -bar_height
	_letterbox_bottom.offset_right = 0.0
	_letterbox_bottom.offset_bottom = 0.0

	if bar_height <= 0.0:
		_letterbox_top.visible = false
		_letterbox_bottom.visible = false
	else:
		_letterbox_top.visible = true
		_letterbox_bottom.visible = true


func _setup_sfx_player() -> void:
	_sfx_player = get_node_or_null("SfxPlayer") as AudioStreamPlayer
	if _sfx_player == null:
		_sfx_player = AudioStreamPlayer.new()
		_sfx_player.name = "SfxPlayer"
		add_child(_sfx_player)
	if AudioServer.get_bus_index(&"SFX") != -1:
		_sfx_player.bus = &"SFX"


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
			if QuestManager.is_completed(quest_id):
				call_deferred("_try_play_for_completed_quest", quest_id)

		"on_area_entered":
			# Legacy: un solo TriggerArea hijo. Preferir ScriptedTrigger en escena.
			var area := get_node_or_null("TriggerArea") as Area2D
			if area == null:
				push_warning("CinematicPlayer: trigger on_area_entered pero no hay hijo Area2D llamado 'TriggerArea'. Usa ScriptedTrigger.")
				return
			var required_quest: String = str(_data.trigger.get("requires_quest", ""))
			var required_active: String = str(_data.trigger.get("requires_quest_active", ""))
			# Cooldown anti-rebote en transiciones: si la cinemática cambia de
			# escena (map→classroom, etc.) y la escena destino tiene un trigger
			# inverso justo donde aparece el jugador, sin esta gracia el player
			# se devuelve solo apenas carga la escena.
			var spawn_grace_msec: int = Time.get_ticks_msec() + 600
			area.body_entered.connect(func(body: Node) -> void:
				if not body.is_in_group("player"):
					return
				if Time.get_ticks_msec() < spawn_grace_msec:
					return
				if not required_quest.is_empty() and not QuestManager.is_completed(required_quest):
					return
				if not required_active.is_empty() and not QuestManager.is_active(required_active):
					return
				play()
			)

		_:
			push_warning("CinematicPlayer: tipo de trigger desconocido '%s'." % trigger_type)


func _try_play_for_completed_quest(quest_id: String) -> void:
	if _data == null or _is_playing:
		return
	if str(_data.trigger.get("quest_id", "")) != quest_id:
		return
	if play_once and Gamemanager.cinematics_played.get(_data.id, false):
		return
	if not QuestManager.is_completed(quest_id):
		return
	await _wait_for_active_dialogues()
	play()


## Reproduce una cinemática one-shot bajo `parent` (p. ej. desde ScriptedTrigger).
static func play_from(path: String, parent: Node, once: bool = true) -> CinematicPlayer:
	if path.is_empty() or parent == null:
		return null
	var packed: PackedScene = load("res://scenes/cinematic/CinematicPlayer.tscn")
	if packed == null:
		push_error("CinematicPlayer: no se pudo cargar CinematicPlayer.tscn")
		return null
	var player := packed.instantiate() as CinematicPlayer
	player.cinematic_json_path = path
	player.auto_play = false
	player.play_once = once
	parent.add_child(player)
	player.play()
	return player


## Inicia la reproducción de la cinemática. Si play_once está activo y ya se
## reprodujo, no hace nada. Se puede llamar manualmente cuando auto_play=false.
func play() -> void:
	if _data == null or _is_playing:
		return
	var is_transition := _has_change_scene_step()
	if play_once and not is_transition and Gamemanager.cinematics_played.get(_data.id, false):
		_black_screen.color.a = 0.0
		return

	_is_playing = true
	_was_skipped = false
	if play_once and not _data.id.is_empty() and not is_transition:
		Gamemanager.cinematics_played[_data.id] = true

	cinematic_started.emit(_data.id)

	for step: CinematicLoader.CinematicStep in _data.steps:
		if not _is_playing:
			break
		await _execute_step(step)

	_is_playing = false
	if not is_inside_tree():
		return
	if not _was_skipped:
		CinematicCameraClass.reset_immediate(get_tree())
		_set_letterbox_immediate(0.0)
		_ensure_player_can_move()
	if _was_skipped:
		cinematic_skipped.emit(_data.id)
	cinematic_finished.emit(_data.id)


## Detiene la cinemática en curso (skip con Interact / E).
func stop() -> void:
	if not _is_playing:
		return
	_was_skipped = true
	_is_playing = false
	_cleanup_playback_state()


func _cleanup_playback_state() -> void:
	if not is_inside_tree():
		return
	_kill_tweens()
	CinematicCameraClass.reset_immediate(get_tree())
	_set_letterbox_immediate(0.0)
	if _black_screen != null:
		_black_screen.color.a = 0.0
	if _runner != null and _runner.is_playing():
		_runner.abort()
	_ensure_player_can_move()


func _ensure_player_can_move() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player")
	if player != null and player.has_method("enable_movement"):
		player.enable_movement()


func _has_change_scene_step() -> bool:
	if _data == null:
		return false
	for step in _data.steps:
		if step.type == "change_scene":
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_playing or not allow_skip:
		return
	if event.is_action_pressed("Interact"):
		stop()
		get_viewport().set_input_as_handled()


func _track_tween(tween: Tween) -> Tween:
	_running_tweens.append(tween)
	tween.finished.connect(func() -> void:
		_running_tweens.erase(tween)
	)
	return tween


func _kill_tweens() -> void:
	for tween in _running_tweens.duplicate():
		if tween != null and tween.is_valid():
			tween.kill()
	_running_tweens.clear()


func _set_letterbox_immediate(bar_height: float) -> void:
	_layout_letterbox(bar_height)


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
	var tween := _track_tween(create_tween())
	tween.tween_property(_black_screen, "color:a", 1.0, duration)
	await tween.finished


func _cmd_fade_from_black(params: Dictionary) -> void:
	var duration: float = float(params.get("duration", 0.5))
	var tween := _track_tween(create_tween())
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
	var voice: AudioStream = null
	var voice_path := str(params.get("voice_path", ""))
	if not voice_path.is_empty():
		voice = load(voice_path) as AudioStream
	_runner.play(data, dialogue_id, voice)
	await _runner.dialogue_finished
	if player != null and player.has_method("enable_movement"):
		player.enable_movement()


func _cmd_move_node(params: Dictionary) -> void:
	var node_path: String = str(params.get("node", ""))
	var duration: float = float(params.get("duration", 1.0))
	var target := _resolve_node2d(node_path)
	if target == null:
		push_warning("CinematicPlayer: move_node — nodo '%s' no encontrado." % node_path)
		return
	var destination: Vector2 = TargetResolver.resolve_point(params, _scene_root())
	var tween := _track_tween(create_tween())
	tween.tween_property(target, "global_position", destination, duration)
	await tween.finished


func _cmd_walk_to(params: Dictionary) -> void:
	var node_path: String = str(params.get("node", ""))
	var actor := _resolve_node2d(node_path)
	if actor == null:
		push_warning("CinematicPlayer: walk_to — nodo '%s' no encontrado." % node_path)
		return
	var destination: Vector2 = TargetResolver.resolve_point(params, _scene_root())
	var speed: float = float(params.get("speed", 120.0))
	var duration: float = float(params.get("duration", 0.0))
	var walk_anim: String = str(params.get("animation", "walk"))
	var idle_anim: String = str(params.get("idle_animation", "idle"))
	var face: bool = bool(params.get("face_direction", true))
	await CinematicActorHelper.walk_node_to(
		self, actor, destination, speed, duration, walk_anim, idle_anim, face
	)


func _cmd_walk_path(params: Dictionary) -> void:
	var node_path: String = str(params.get("node", ""))
	var actor := _resolve_node2d(node_path)
	if actor == null:
		push_warning("CinematicPlayer: walk_path — nodo '%s' no encontrado." % node_path)
		return
	var points: Array[Vector2] = TargetResolver.resolve_path(params, _scene_root())
	if points.is_empty():
		push_warning("CinematicPlayer: walk_path — to_path vacío o inválido.")
		return
	var speed: float = float(params.get("speed", 120.0))
	var wait_per_point: float = float(params.get("wait_per_point", 0.0))
	var walk_anim: String = str(params.get("animation", "walk"))
	var idle_anim: String = str(params.get("idle_animation", "idle"))
	var face: bool = bool(params.get("face_direction", true))
	for point in points:
		if not _is_playing:
			break
		await CinematicActorHelper.walk_node_to(
			self, actor, point, speed, 0.0, walk_anim, idle_anim, face
		)
		if wait_per_point > 0.0:
			await get_tree().create_timer(wait_per_point).timeout


func _cmd_face_direction(params: Dictionary) -> void:
	var node_path: String = str(params.get("node", ""))
	var actor := _resolve_node2d(node_path)
	if actor == null:
		push_warning("CinematicPlayer: face_direction — nodo '%s' no encontrado." % node_path)
		return
	var sprite := CinematicActorHelper.find_sprite(actor)
	if sprite == null:
		return
	var direction: String = str(params.get("direction", ""))
	var look_at_path: String = str(params.get("look_at_node", ""))
	var idle_anim: String = str(params.get("idle_animation", "idle"))
	if not look_at_path.is_empty():
		var look_target := _resolve_node2d(look_at_path)
		if look_target != null:
			CinematicActorHelper.face_toward(sprite, actor.global_position, look_target.global_position, idle_anim)
			return
	if direction.is_empty():
		push_warning("CinematicPlayer: face_direction sin 'direction' ni 'look_at_node'.")
		return
	if direction.to_lower() == "left":
		sprite.flip_h = true
	elif direction.to_lower() == "right":
		sprite.flip_h = false
	CinematicActorHelper.play_idle(sprite, idle_anim)


func _cmd_play_animation(params: Dictionary) -> void:
	var node_path: String = str(params.get("node", ""))
	var actor := _resolve_node2d(node_path)
	if actor == null:
		actor = _scene_root().get_node_or_null(node_path)
	if actor == null:
		push_warning("CinematicPlayer: play_animation — nodo '%s' no encontrado." % node_path)
		return
	var animation: String = str(params.get("animation", ""))
	if animation.is_empty():
		push_warning("CinematicPlayer: play_animation sin 'animation'.")
		return
	var wait_finish: bool = bool(params.get("wait_finish", false))
	var idle_anim: String = str(params.get("idle_animation", "idle"))
	await CinematicActorHelper.play_animation_on(self, actor, animation, wait_finish, idle_anim)


func _cmd_set_collision(params: Dictionary) -> void:
	var node_path: String = str(params.get("node", ""))
	var target := _scene_root().get_node_or_null(node_path)
	if target == null:
		push_warning("CinematicPlayer: set_collision — nodo '%s' no encontrado." % node_path)
		return
	var enabled: bool = bool(params.get("enabled", true))
	CinematicActorHelper.set_collision_enabled(target, enabled)


func _cmd_enable_barrier(params: Dictionary) -> void:
	var barrier_id: String = str(params.get("id", ""))
	if barrier_id.is_empty():
		push_warning("CinematicPlayer: enable_barrier sin 'id'.")
		return
	var barrier = ScriptedBarrierClass.find_by_id(barrier_id)
	if barrier == null:
		push_warning("CinematicPlayer: barrera '%s' no encontrada." % barrier_id)
		return
	barrier.set_active(true)


func _cmd_disable_barrier(params: Dictionary) -> void:
	var barrier_id: String = str(params.get("id", ""))
	if barrier_id.is_empty():
		push_warning("CinematicPlayer: disable_barrier sin 'id'.")
		return
	var barrier = ScriptedBarrierClass.find_by_id(barrier_id)
	if barrier == null:
		push_warning("CinematicPlayer: barrera '%s' no encontrada." % barrier_id)
		return
	barrier.set_active(false)


func _cmd_start_battle(params: Dictionary) -> void:
	var battle_scene_path: String = str(params.get("battle_scene_path", ""))
	if battle_scene_path.is_empty():
		push_warning("CinematicPlayer: start_battle sin 'battle_scene_path'.")
		return
	var battle_scene: PackedScene = load(battle_scene_path) as PackedScene
	if battle_scene == null:
		push_error("CinematicPlayer: start_battle — escena inválida: %s" % battle_scene_path)
		return

	var chart_path: String = str(params.get("chart_path", ""))
	var music_path: String = str(params.get("music_path", ""))
	var return_npc_id: String = str(params.get("return_npc_id", ""))

	var music: AudioStream = null
	if not music_path.is_empty():
		music = load(music_path) as AudioStream

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var return_position := Vector2.ZERO
	if player != null:
		return_position = player.global_position

	Gamemanager.return_scene_path = str(get_tree().current_scene.scene_file_path)
	Gamemanager.return_position = return_position
	Gamemanager.pending_npc_id = return_npc_id
	Gamemanager.pending_dialogue_result = ""
	Gamemanager.set_pending_battle_chart_path(chart_path)
	Gamemanager.set_pending_battle_music(music)

	_is_playing = false
	get_tree().change_scene_to_packed(battle_scene)


func _cmd_follower_lead(params: Dictionary) -> void:
	var follower = _resolve_follower(params)
	if follower == null:
		return
	var path_node_path: String = str(params.get("path_node", params.get("to_path", "")))
	if path_node_path.is_empty():
		push_warning("CinematicPlayer: follower_lead sin 'path_node' o 'to_path'.")
		return
	var lead_speed: float = float(params.get("speed", follower.speed))
	follower.speed = lead_speed
	var wait_for_player := bool(params.get("wait_for_player", true))
	var previous_wait: float = follower.wait_distance
	if not wait_for_player:
		follower.wait_distance = 0.0
	follower.lead_along(NodePath(path_node_path))
	if bool(params.get("wait_for_arrival", true)):
		await follower.route_completed
	if not wait_for_player:
		follower.wait_distance = previous_wait


func _cmd_follower_follow(params: Dictionary) -> void:
	var follower = _resolve_follower(params)
	if follower == null:
		return
	var target_path: String = str(params.get("target", "Player"))
	var target := _resolve_node2d(target_path)
	if target == null:
		push_warning("CinematicPlayer: follower_follow — target '%s' no encontrado." % target_path)
		return
	var follow_speed: float = float(params.get("speed", follower.speed))
	follower.speed = follow_speed
	follower.follow(target)


func _cmd_follower_stop(params: Dictionary) -> void:
	var follower = _resolve_follower(params)
	if follower == null:
		return
	follower.stop()


func _resolve_follower(params: Dictionary):
	var node_path: String = str(params.get("node", ""))
	if node_path.is_empty() or _scene_root() == null:
		push_warning("CinematicPlayer: comando follower sin 'node'.")
		return null
	var target := _scene_root().get_node_or_null(node_path)
	if target == null:
		push_warning("CinematicPlayer: follower — nodo '%s' no encontrado." % node_path)
		return null
	if target is Follower:
		return target
	for child in target.get_children():
		if child is Follower:
			return child
	push_warning("CinematicPlayer: '%s' no tiene hijo Follower." % node_path)
	return null


func _cmd_camera_focus(params: Dictionary) -> void:
	var target_path: String = str(params.get("target", params.get("to_node", "")))
	var target := _resolve_node2d(target_path)
	if target == null:
		push_warning("CinematicPlayer: camera_focus — target '%s' no encontrado." % target_path)
		return
	var duration: float = float(params.get("duration", 0.6))
	var zoom_value: float = float(params.get("zoom", 0.0))
	await CinematicCameraClass.focus_on(self, target, duration, zoom_value)


func _cmd_camera_release(params: Dictionary) -> void:
	var duration: float = float(params.get("duration", 0.6))
	await CinematicCameraClass.release(self, duration)


func _cmd_shake_camera(params: Dictionary) -> void:
	var intensity: float = float(params.get("intensity", 8.0))
	var duration: float = float(params.get("duration", 0.3))
	await CinematicCameraClass.shake(self, intensity, duration, func() -> bool:
		return _is_playing
	)


func _cmd_letterbox(params: Dictionary) -> void:
	var enabled: bool = bool(params.get("enabled", true))
	var bar_height: float = float(params.get("bar_height", 64.0))
	var duration: float = float(params.get("duration", 0.3))
	var target_height: float = bar_height if enabled else 0.0
	var start_height: float = _letterbox_top.size.y if _letterbox_top != null else 0.0
	var tween := _track_tween(create_tween())
	tween.tween_method(_layout_letterbox, start_height, target_height, duration)
	await tween.finished


func _cmd_play_sfx(params: Dictionary) -> void:
	var stream_path: String = str(params.get("stream_path", ""))
	if stream_path.is_empty():
		push_warning("CinematicPlayer: play_sfx sin 'stream_path'.")
		return
	var stream: AudioStream = load(stream_path) as AudioStream
	if stream == null:
		push_warning("CinematicPlayer: play_sfx — stream inválido: %s" % stream_path)
		return
	if _sfx_player == null:
		return

	var bus_name: String = str(params.get("bus", "SFX"))
	var volume_db: float = float(params.get("volume_db", 0.0))
	var wait_finish: bool = bool(params.get("wait_finish", false))
	_sfx_player.volume_db = volume_db
	if AudioServer.get_bus_index(StringName(bus_name)) != -1:
		_sfx_player.bus = StringName(bus_name)
	_sfx_player.stream = stream
	_sfx_player.play()
	if wait_finish:
		await _sfx_player.finished


func _cmd_wait_for_player_near(params: Dictionary) -> void:
	var ref_path: String = str(params.get("to_node", params.get("node", "")))
	var ref_node := _resolve_node2d(ref_path)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if ref_node == null or player == null:
		push_warning("CinematicPlayer: wait_for_player_near — referencia o player no encontrado.")
		return
	var distance: float = float(params.get("distance", 64.0))
	var timeout_s: float = float(params.get("timeout", 0.0))
	var start_ms: int = Time.get_ticks_msec()
	while _is_playing:
		if player.global_position.distance_to(ref_node.global_position) <= distance:
			return
		if timeout_s > 0.0 and float(Time.get_ticks_msec() - start_ms) >= timeout_s * 1000.0:
			return
		await get_tree().process_frame


func _scene_root() -> Node:
	return get_tree().current_scene


func _resolve_node2d(node_path: String) -> Node2D:
	if node_path.is_empty() or _scene_root() == null:
		return null
	return _scene_root().get_node_or_null(node_path) as Node2D


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
	_is_playing = false
	get_tree().change_scene_to_file(path)
