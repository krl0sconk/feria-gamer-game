class_name ChartEditor
extends Node2D

const ARROW_SCENE: PackedScene = preload("res://scenes/rhythm/NoteArrow.tscn")
const LANE_ACTIONS: Array[String] = ["note_left", "note_down", "note_up", "note_right"]
const LANE_LABELS: Dictionary = {
	"note_left": "←", "note_down": "↓", "note_up": "↑", "note_right": "→",
}
const ACTION_TO_DIRECTION: Dictionary = {
	"note_left": NoteArrow.Direction.LEFT,
	"note_down": NoteArrow.Direction.DOWN,
	"note_up": NoteArrow.Direction.UP,
	"note_right": NoteArrow.Direction.RIGHT,
}
# Pixels por milisegundo (misma velocidad que battle: 400px/s = 0.4px/ms)
const PX_PER_MS: float = 0.4
const SEEK_STEP_MS: float = 100.0
const SEEK_FAST_MS: float = 1000.0
const SELECT_THRESHOLD_MS: float = 120.0

const SPEED_OPTIONS: Array[float] = [0.25, 0.5, 0.75, 1.0]

var _chart_data: ChartLoader.ChartData = ChartLoader.ChartData.new()
var _is_playing: bool = false
var _current_ms: float = 0.0
var _audio_length_ms: float = 1000.0
var _save_path: String = ""
var _speed_index: int = 3  # default 1.0x
# Mapa NoteData → NoteArrow para sincronizar visual con datos
var _arrow_map: Dictionary = {}
# Lane X positions (local al contenedor Notes)
var _lane_x: Dictionary = {}
var _target_y_local: float = 0.0

@onready var _audio: AudioStreamPlayer = $AudioPlayer
@onready var _notes_node: Node2D = $Notes
@onready var _targets_node: Node2D = $Targets
@onready var _left_target: NoteTarget = $Targets/LeftTarget
@onready var _down_target: NoteTarget = $Targets/DownTarget
@onready var _up_target: NoteTarget = $Targets/UpTarget
@onready var _right_target: NoteTarget = $Targets/RightTarget
@onready var _time_label: Label = $EditorUI/TopBar/TimeLabel
@onready var _bpm_spin: SpinBox = $EditorUI/TopBar/BPMSpin
@onready var _title_edit: LineEdit = $EditorUI/TopBar/TitleEdit
@onready var _file_dialog_audio: FileDialog = $EditorUI/FileDialogAudio
@onready var _file_dialog_save: FileDialog = $EditorUI/FileDialogSave
@onready var _file_dialog_load: FileDialog = $EditorUI/FileDialogLoad


func _ready() -> void:
	# Quitar focus de botones para que flechas no los naveguen
	for node in _get_all_children(self):
		if node is Button:
			node.focus_mode = Control.FOCUS_NONE
	_bpm_spin.value = _chart_data.bpm
	_bpm_spin.value_changed.connect(func(v): _chart_data.bpm = v)
	_title_edit.text_changed.connect(func(t): _chart_data.title = t)
	# Soltar focus con Enter o Escape
	_title_edit.text_submitted.connect(func(_t): _title_edit.release_focus())
	_bpm_spin.get_line_edit().text_submitted.connect(func(_t): _bpm_spin.get_line_edit().release_focus())
	_setup_lanes()


func _process(_delta: float) -> void:
	if _is_playing:
		_current_ms = _audio.get_playback_position() * 1000.0
		if _current_ms >= _audio_length_ms:
			_toggle_play(false)
	_scroll_notes()
	_time_label.text = "%s / %s [%.0f%%]" % [_format_time(_current_ms), _format_time(_audio_length_ms), SPEED_OPTIONS[_speed_index] * 100.0]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var handled := true
	if event.keycode == KEY_ESCAPE:
		get_viewport().gui_release_focus()
	elif event.keycode == KEY_P:
		_toggle_play(not _is_playing)
	elif event.keycode == KEY_DELETE:
		_delete_nearest_note()
	elif event.keycode == KEY_S and event.ctrl_pressed:
		_save_chart()
	elif event.keycode == KEY_MINUS or event.keycode == KEY_EQUAL:
		# - baja velocidad, + (=/+) sube velocidad
		if event.keycode == KEY_MINUS:
			_speed_index = maxi(_speed_index - 1, 0)
		else:
			_speed_index = mini(_speed_index + 1, SPEED_OPTIONS.size() - 1)
		_apply_speed()
	elif event.keycode == KEY_A or event.keycode == KEY_D:
		var dir: float = -1.0 if event.keycode == KEY_A else 1.0
		var step: float = SEEK_FAST_MS if event.shift_pressed else SEEK_STEP_MS
		_seek(_current_ms + dir * step)
	else:
		for action in LANE_ACTIONS:
			if event.is_action_pressed(action):
				_place_note(action)
				break
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


# ── Setup ─────────────────────────────────────────────────────────────────────
func _setup_lanes() -> void:
	_lane_x = {
		"note_left":  _notes_node.to_local(_left_target.global_position).x,
		"note_down":  _notes_node.to_local(_down_target.global_position).x,
		"note_up":    _notes_node.to_local(_up_target.global_position).x,
		"note_right": _notes_node.to_local(_right_target.global_position).x,
	}
	_target_y_local = _notes_node.to_local(_left_target.global_position).y


# ── Scroll visual ────────────────────────────────────────────────────────────
func _scroll_notes() -> void:
	# Mover contenedor para que note en _current_ms quede alineado con targets
	_notes_node.position.y = _targets_node.position.y + _current_ms * PX_PER_MS


# ── Arrows ────────────────────────────────────────────────────────────────────
func _create_arrow(note: NoteData) -> NoteArrow:
	var arrow: NoteArrow = ARROW_SCENE.instantiate() as NoteArrow
	arrow.direction = ACTION_TO_DIRECTION[note.action]
	var local_y: float = -note.time_ms * PX_PER_MS / _notes_node.scale.y
	arrow.position = Vector2(_lane_x[note.action], local_y)
	_notes_node.add_child(arrow)
	# Desactivar después de add_child para que no caiga ni se auto-destruya
	arrow.set_process(false)
	arrow.set_physics_process(false)
	return arrow


func _rebuild_arrows() -> void:
	# Limpiar todas las flechas existentes
	for arrow in _arrow_map.values():
		if is_instance_valid(arrow):
			arrow.queue_free()
	_arrow_map.clear()
	for note in _chart_data.notes:
		_arrow_map[note] = _create_arrow(note)


# ── Audio ─────────────────────────────────────────────────────────────────────
func _on_load_audio_pressed() -> void:
	_file_dialog_audio.popup_centered(Vector2i(800, 500))


func _on_audio_file_selected(path: String) -> void:
	var stream = load(path)
	if stream is AudioStream:
		_audio.stream = stream
		_audio_length_ms = stream.get_length() * 1000.0
		_current_ms = 0.0
		_toggle_play(false)


# ── Chart I/O ─────────────────────────────────────────────────────────────────
func _on_load_chart_pressed() -> void:
	_file_dialog_load.popup_centered(Vector2i(800, 500))


func _on_chart_file_selected(path: String) -> void:
	_chart_data = ChartLoader.load_json(path)
	_save_path = path
	_bpm_spin.value = _chart_data.bpm
	_title_edit.text = _chart_data.title
	_rebuild_arrows()
	print("[EDITOR] Chart cargado: %s (%d notas)" % [path, _chart_data.notes.size()])


func _save_chart() -> void:
	if _save_path.is_empty():
		_file_dialog_save.popup_centered(Vector2i(800, 500))
		return
	_do_save(_save_path)


func _on_save_file_selected(path: String) -> void:
	_save_path = path
	_do_save(path)


func _do_save(path: String) -> void:
	_chart_data.bpm = _bpm_spin.value
	_chart_data.title = _title_edit.text
	ChartLoader.save_json(path, _chart_data)
	print("[EDITOR] Guardado: %s (%d notas)" % [path, _chart_data.notes.size()])


# ── Playback ──────────────────────────────────────────────────────────────────
func _toggle_play(play: bool) -> void:
	_is_playing = play
	if play and _audio.stream != null:
		_apply_speed()
		_audio.play(_current_ms / 1000.0)
	else:
		_audio.stop()


func _apply_speed() -> void:
	var spd: float = SPEED_OPTIONS[_speed_index]
	_audio.pitch_scale = spd
	# Si está reproduciendo, reiniciar desde la posición actual para aplicar inmediatamente
	if _is_playing and _audio.stream != null:
		_audio.play(_current_ms / 1000.0)
	print("[EDITOR] Velocidad: %.0f%%" % (spd * 100.0))


func _seek(ms: float) -> void:
	_current_ms = clampf(ms, 0.0, _audio_length_ms)
	if _is_playing and _audio.stream != null:
		_audio.play(_current_ms / 1000.0)


# ── Edición de notas ─────────────────────────────────────────────────────────
func _place_note(action: String) -> void:
	var t: float = _current_ms
	# Evitar duplicados exactos
	for n in _chart_data.notes:
		if absf(n.time_ms - t) < 1.0 and n.action == action:
			return
	var note := NoteData.new()
	note.time_ms = t
	note.action = action
	_chart_data.notes.append(note)
	_chart_data.notes.sort_custom(func(a, b): return a.time_ms < b.time_ms)
	_arrow_map[note] = _create_arrow(note)
	print("[EDITOR] + %s @ %s" % [LANE_LABELS[action], _format_time(t)])


func _delete_nearest_note() -> void:
	if _chart_data.notes.is_empty():
		return
	var best_idx: int = -1
	var best_diff: float = SELECT_THRESHOLD_MS + 1.0
	for i in range(_chart_data.notes.size()):
		var diff: float = absf(_chart_data.notes[i].time_ms - _current_ms)
		if diff < best_diff:
			best_diff = diff
			best_idx = i
	if best_idx >= 0 and best_diff <= SELECT_THRESHOLD_MS:
		var note: NoteData = _chart_data.notes[best_idx]
		if _arrow_map.has(note):
			var arrow = _arrow_map[note]
			if is_instance_valid(arrow):
				arrow.queue_free()
			_arrow_map.erase(note)
		print("[EDITOR] - %s @ %s" % [LANE_LABELS[note.action], _format_time(note.time_ms)])
		_chart_data.notes.remove_at(best_idx)


# ── Utilidades ────────────────────────────────────────────────────────────────
func _format_time(ms: float) -> String:
	var total_s: float = maxf(ms / 1000.0, 0.0)
	var mins: int = int(total_s) / 60
	var secs: int = int(total_s) % 60
	var millis: int = int(ms) % 1000
	return "%d:%02d.%03d" % [mins, secs, millis]


func _get_all_children(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_get_all_children(child))
	return result
