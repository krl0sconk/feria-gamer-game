class_name BattleHUD
extends CanvasLayer

const ARROW_SCENE: PackedScene = preload("res://scenes/rhythm/note_arrow.tscn")
const SPAWN_Y: float = -500.0
const ACTION_TO_DIRECTION: Dictionary = {
	"note_left": NoteArrow.Direction.LEFT,
	"note_down": NoteArrow.Direction.DOWN,
	"note_up": NoteArrow.Direction.UP,
	"note_right": NoteArrow.Direction.RIGHT,
}

@export var notes_container: NodePath = NodePath("")
@export var root_path: NodePath = NodePath("Root")
@export var player_hp_bar_path: NodePath = NodePath("Root/PlayerHPBar")
@export var enemy_hp_bar_path: NodePath = NodePath("Root/EnemyHPBar")
@export var score_label_path: NodePath = NodePath("Root/ScoreLabel")
@export var combo_label_path: NodePath = NodePath("Root/ComboLabel")
@export var rating_feedback_path: NodePath = NodePath("Root/RatingFeedback")

## Tamaño base de diseño del HUD. El Root Control se mantiene a este tamaño
## en el editor para edición visual y se reescala al tamaño real del viewport
## en runtime, conservando el layout por anchors.
@export var design_size: Vector2 = Vector2(1280, 720)

@export_group("Combo bounce")
@export var combo_pop_scale: float = 1.5
@export var combo_pop_seconds: float = 0.18

@export_group("SFX")
@export var perfect_sfx: AudioStream
@export var good_sfx: AudioStream
@export var miss_sfx: AudioStream
@export var combo_sfx: AudioStream
@export var sfx_bus: StringName = &"SFX"
@export var sfx_volume_db: float = -14.0

var _arrow_queues: Dictionary = {
	"note_left": [], "note_down": [], "note_up": [], "note_right": [],
}
var _notes_node: Node2D
var _targets: Dictionary = {}
var _lane_x: Dictionary = {}
var _target_y: float = 0.0
var arrow_travel_ms: float = 0.0

var _root: Control
var _player_hp_bar: ProgressBar
var _enemy_hp_bar: ProgressBar
var _score_label: Label
var _combo_label: Label
var _rating_feedback: RatingFeedback
var _vignette: ColorRect
var _vignette_tween: Tween
var _rating_sfx_players: Dictionary = {}
var _combo_sfx_player: AudioStreamPlayer = null
var _last_combo_value: int = 0


func _ready() -> void:
	_notes_node = get_node(notes_container) as Node2D
	_root = get_node_or_null(root_path) as Control
	_player_hp_bar = get_node_or_null(player_hp_bar_path) as ProgressBar
	_enemy_hp_bar = get_node_or_null(enemy_hp_bar_path) as ProgressBar
	_score_label = get_node_or_null(score_label_path) as Label
	_combo_label = get_node_or_null(combo_label_path) as Label
	_rating_feedback = get_node_or_null(rating_feedback_path) as RatingFeedback
	if _combo_label != null:
		_combo_label.pivot_offset = _combo_label.size / 2.0
	_fit_root_to_viewport()
	get_viewport().size_changed.connect(_fit_root_to_viewport)
	_setup_vignette()
	_setup_sfx()


# Mantiene el Root del HUD anclado al viewport real, conservando el design_size
# como mínimo (para visibilidad en el editor). Los anchors de los hijos hacen
# el resto del trabajo.
func _setup_vignette() -> void:
	if _root == null:
		return
	var shader := load("res://shaders/vignette.gdshader") as Shader
	if shader == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("strength", 0.0)
	_vignette = ColorRect.new()
	_vignette.name = "Vignette"
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.material = mat
	_root.add_child(_vignette)


func _setup_sfx() -> void:
	_rating_sfx_players = {
		"Perfect": _create_sfx_player(perfect_sfx),
		"Good": _create_sfx_player(good_sfx),
		"Miss": _create_sfx_player(miss_sfx),
	}
	_combo_sfx_player = _create_sfx_player(combo_sfx)


func _create_sfx_player(stream: AudioStream) -> AudioStreamPlayer:
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = sfx_volume_db
	if AudioServer.get_bus_index(sfx_bus) != -1:
		player.bus = sfx_bus
	else:
		player.bus = &"Master"
	add_child(player)
	return player


func _fit_root_to_viewport() -> void:
	if _root == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_root.custom_minimum_size = design_size
	_root.size = vp_size
	_root.position = Vector2.ZERO


func setup_targets(left: NoteTarget, down: NoteTarget, up: NoteTarget, right: NoteTarget) -> void:
	_targets = {
		"note_left": left, "note_down": down, "note_up": up, "note_right": right,
	}
	# Global → local del contenedor de flechas
	_lane_x = {
		"note_left":  _notes_node.to_local(left.global_position).x,
		"note_down":  _notes_node.to_local(down.global_position).x,
		"note_up":    _notes_node.to_local(up.global_position).x,
		"note_right": _notes_node.to_local(right.global_position).x,
	}
	_target_y = _notes_node.to_local(left.global_position).y
	arrow_travel_ms = (_target_y - SPAWN_Y) / 400.0 * 1000.0


func _on_composer_note_expected(note: NoteData) -> void:
	if not _lane_x.has(note.action):
		return
	var arrow: NoteArrow = ARROW_SCENE.instantiate() as NoteArrow
	arrow.direction = ACTION_TO_DIRECTION[note.action]
	arrow.target_y = _target_y
	arrow.position = Vector2(_lane_x[note.action], SPAWN_Y)
	arrow.is_fake = note.is_fake
	arrow.expired.connect(_on_arrow_expired.bind(note.action, arrow))
	_notes_node.add_child(arrow)
	_arrow_queues[note.action].append(arrow)


func _on_judge_note_result(player_action: String, expected_action: String, timing: String, success: bool) -> void:
	var flash_action: String = player_action if _targets.has(player_action) else expected_action
	if _targets.has(flash_action):
		if success:
			_targets[flash_action].flash_hit()
			_consume_oldest_arrow(expected_action)
		else:
			_targets[flash_action].flash_miss()
	if _rating_feedback != null:
		_rating_feedback.on_note_result(player_action, expected_action, timing, success)
	_play_rating_sfx(timing, success)


func _play_rating_sfx(timing: String, success: bool) -> void:
	var rating: String = timing if success else "Miss"
	if rating != "Perfect" and rating != "Good":
		rating = "Miss"
	var player := _rating_sfx_players.get(rating, null) as AudioStreamPlayer
	if player != null:
		player.play()


# Conectado a PlayerInput.button_pressed para iluminar el target al presionar.
func on_player_pressed(action: String) -> void:
	if _targets.has(action):
		_targets[action].flash_press()


func _on_arrow_expired(action: String, arrow: NoteArrow) -> void:
	_arrow_queues[action].erase(arrow)


func clear_arrows() -> void:
	for action in _arrow_queues:
		for arrow in _arrow_queues[action]:
			if is_instance_valid(arrow):
				(arrow as NoteArrow).destroy()
		_arrow_queues[action].clear()


func _consume_oldest_arrow(action: String) -> void:
	var queue: Array = _arrow_queues[action]
	if queue.is_empty():
		return
	var obj = queue.pop_front()
	if is_instance_valid(obj):
		(obj as NoteArrow).destroy()


func on_player_hp_updated(hp: int, max_hp: int) -> void:
	if _player_hp_bar != null:
		_player_hp_bar.max_value = max_hp
		_player_hp_bar.value = hp
	if _vignette != null and _vignette.material is ShaderMaterial:
		var mat := _vignette.material as ShaderMaterial
		var target_strength: float = 1.0 - (float(hp) / float(max_hp))
		var current_strength: float = mat.get_shader_parameter("strength")
		if _vignette_tween:
			_vignette_tween.kill()
		_vignette_tween = create_tween()
		_vignette_tween.tween_method(
			func(v: float) -> void: mat.set_shader_parameter("strength", v),
			current_strength, target_strength, 0.25
		)


func on_enemy_hp_updated(hp: float, max_hp: float) -> void:
	if _enemy_hp_bar == null:
		return
	_enemy_hp_bar.max_value = max_hp
	_enemy_hp_bar.value = hp


func on_score_updated(score: int) -> void:
	if _score_label == null:
		return
	_score_label.text = "%d" % score


func on_combo_updated(combo: int, _max_combo: int) -> void:
	if combo > _last_combo_value and _combo_sfx_player != null:
		_combo_sfx_player.play()
	_last_combo_value = combo
	if _combo_label == null:
		return
	if combo <= 0:
		_combo_label.text = ""
	else:
		_combo_label.text = "x%d" % combo
		_combo_label.pivot_offset = _combo_label.size / 2.0
		_combo_label.scale = Vector2(combo_pop_scale, combo_pop_scale)
		var tween: Tween = create_tween()
		tween.tween_property(_combo_label, "scale", Vector2.ONE, combo_pop_seconds)
