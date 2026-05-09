class_name ChartEditor
extends Node2D

const ARROW_SCENE: PackedScene = preload("res://scenes/rhythm/note_arrow.tscn")
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
const LANE_CLICK_THRESHOLD_PX: float = 40.0

const SPEED_OPTIONS: Array[float] = [0.25, 0.5, 0.75, 1.0]

const BEAT_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const SUBDIV_COLOR := Color(1.0, 1.0, 1.0, 0.12)
const PHASE_LINE_COLOR := Color(1.0, 0.45, 0.1, 0.85)

var _chart_data: ChartLoader.ChartData = ChartLoader.ChartData.new()
var _is_playing: bool = false
var _current_ms: float = 0.0
var _audio_length_ms: float = 1000.0
var _save_path: String = ""
var _speed_index: int = 3  # default 1.0x
var _arrow_map: Dictionary = {}
var _lane_x: Dictionary = {}
var _target_y_local: float = 0.0
var _subdivision: int = 4  # grid lines per beat
var _current_editor_phase: int = 0
var _dragging_note: NoteData = null
var _drag_started: bool = false

@onready var _audio: AudioStreamPlayer = $AudioPlayer
@onready var _audio2: AudioStreamPlayer = $AudioPlayer2
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
@onready var _file_dialog_audio2: FileDialog = $EditorUI/FileDialogAudio2
@onready var _file_dialog_save: FileDialog = $EditorUI/FileDialogSave
@onready var _file_dialog_load: FileDialog = $EditorUI/FileDialogLoad
@onready var _bpm2_spin: SpinBox = $EditorUI/Phase2Bar/BPM2Spin
@onready var _phase2_start_label: Label = $EditorUI/Phase2Bar/Phase2StartLabel
@onready var _subdiv_spin: SpinBox = $EditorUI/Phase2Bar/SubdivSpin


func _ready() -> void:
	for node in _get_all_children(self):
		if node is Button:
			node.focus_mode = Control.FOCUS_NONE

	# Ensure at least one phase
	if _chart_data.phases.is_empty():
		var p1 := ChartLoader.PhaseData.new()
		p1.bpm = 120.0
		_chart_data.phases.append(p1)

	_bpm_spin.value = _chart_data.phases[0].bpm
	_bpm_spin.value_changed.connect(func(v: float) -> void:
		_chart_data.phases[0].bpm = v
	)
	_bpm2_spin.value_changed.connect(func(v: float) -> void:
		if _chart_data.phases.size() >= 2:
			_chart_data.phases[1].bpm = v
	)
	_subdiv_spin.value_changed.connect(func(v: float) -> void:
		_subdivision = int(v)
	)
	_subdivision = int(_subdiv_spin.value)

	_title_edit.text_changed.connect(func(t: String) -> void: _chart_data.title = t)
	_title_edit.text_submitted.connect(func(_t: String) -> void: _title_edit.release_focus())
	_bpm_spin.get_line_edit().text_submitted.connect(func(_t: String) -> void: _bpm_spin.get_line_edit().release_focus())
	_bpm2_spin.get_line_edit().text_submitted.connect(func(_t: String) -> void: _bpm2_spin.get_line_edit().release_focus())
	_audio.finished.connect(func() -> void:
		if _is_playing and _current_editor_phase == 0:
			_toggle_play(false)
	)
	_audio2.finished.connect(func() -> void:
		if _is_playing and _current_editor_phase == 1:
			_toggle_play(false)
	)
	_setup_lanes()


func _process(_delta: float) -> void:
	if _is_playing:
		_update_editor_playback()
	_scroll_notes()
	_time_label.text = "%s / %s [%.0f%%]" % [_format_time(_current_ms), _format_time(_audio_length_ms), SPEED_OPTIONS[_speed_index] * 100.0]
	queue_redraw()


func _draw() -> void:
	if _chart_data.phases.is_empty() or _lane_x.is_empty():
		return

	var target_y: float = _targets_node.position.y
	var vp_size: Vector2 = get_viewport_rect().size
	var t_top: float = _current_ms + (target_y + vp_size.y / 2.0) / PX_PER_MS
	var t_bot: float = _current_ms - (vp_size.y / 2.0 - target_y) / PX_PER_MS

	var x_left: float = _notes_node.position.x + _lane_x["note_left"] * _notes_node.scale.x - 20.0
	var x_right: float = _notes_node.position.x + _lane_x["note_right"] * _notes_node.scale.x + 20.0

	for i in range(_chart_data.phases.size()):
		var phase: ChartLoader.PhaseData = _chart_data.phases[i]
		var phase_end: float
		if i + 1 < _chart_data.phases.size():
			phase_end = _chart_data.phases[i + 1].start_ms
		else:
			phase_end = _audio_length_ms

		var beat_ms: float = (60.0 / phase.bpm) * 1000.0
		var subdiv_ms: float = beat_ms / float(_subdivision)

		var t_start_clipped: float = maxf(t_bot, phase.start_ms)
		var t_end_clipped: float = minf(t_top, phase_end)
		if t_start_clipped > t_end_clipped:
			continue

		var t: float = ceil(t_start_clipped / subdiv_ms) * subdiv_ms
		while t <= t_end_clipped:
			var y: float = target_y + (_current_ms - t) * PX_PER_MS
			var beat_offset: float = fmod(t - phase.start_ms, beat_ms)
			var is_beat: bool = absf(beat_offset) < 0.5 or absf(beat_offset - beat_ms) < 0.5
			draw_line(
				Vector2(x_left, y), Vector2(x_right, y),
				BEAT_COLOR if is_beat else SUBDIV_COLOR,
				2.0 if is_beat else 1.0
			)
			t += subdiv_ms

		if i > 0:
			var by: float = target_y + (_current_ms - phase.start_ms) * PX_PER_MS
			draw_line(Vector2(x_left - 10.0, by), Vector2(x_right + 10.0, by), PHASE_LINE_COLOR, 3.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_left_press(event.position)
			else:
				_on_left_release()
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_delete_note_at_mouse(event.position)
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseMotion and _dragging_note != null:
		_drag_note_to(event.position)
		get_viewport().set_input_as_handled()
		return

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
				_place_note_at(action, _snap_to_grid(_current_ms))
				break
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _setup_lanes() -> void:
	_lane_x = {
		"note_left":  _notes_node.to_local(_left_target.global_position).x,
		"note_down":  _notes_node.to_local(_down_target.global_position).x,
		"note_up":    _notes_node.to_local(_up_target.global_position).x,
		"note_right": _notes_node.to_local(_right_target.global_position).x,
	}
	_target_y_local = _notes_node.to_local(_left_target.global_position).y


func _scroll_notes() -> void:
	_notes_node.position.y = _targets_node.position.y + _current_ms * PX_PER_MS


func _update_editor_playback() -> void:
	if _current_editor_phase == 0:
		if _audio.playing:
			_current_ms = _audio.get_playback_position() * 1000.0
		_check_editor_phase_transition()
	elif _current_editor_phase == 1 and _audio2.playing:
		_current_ms = _chart_data.phases[1].start_ms + _audio2.get_playback_position() * 1000.0
	if _current_ms >= _audio_length_ms:
		_toggle_play(false)


func _check_editor_phase_transition() -> void:
	if _chart_data.phases.size() < 2:
		return
	var p2_start: float = _chart_data.phases[1].start_ms
	if _current_ms >= p2_start and _audio2.stream != null:
		_current_editor_phase = 1
		_audio.stop()
		_audio2.pitch_scale = SPEED_OPTIONS[_speed_index]
		_audio2.play((_current_ms - p2_start) / 1000.0)


func _on_left_press(screen_pos: Vector2) -> void:
	var existing: NoteData = _find_note_near_mouse(screen_pos)
	if existing != null:
		_dragging_note = existing
		_drag_started = false
		return
	# Empty area → place new note
	var world_pos: Vector2 = get_canvas_transform().affine_inverse() * screen_pos
	var action: String = _lane_from_world_x(world_pos.x)
	if action.is_empty():
		return
	var raw_ms: float = _current_ms + (_targets_node.position.y - world_pos.y) / PX_PER_MS
	var snapped_ms: float = _snap_to_grid(raw_ms)
	if snapped_ms < 0.0 or snapped_ms > _audio_length_ms:
		return
	_place_note_at(action, snapped_ms)


func _on_left_release() -> void:
	if _dragging_note == null:
		return
	if _drag_started:
		_chart_data.notes.sort_custom(func(a: NoteData, b: NoteData) -> bool: return a.time_ms < b.time_ms)
	_dragging_note = null
	_drag_started = false


func _drag_note_to(screen_pos: Vector2) -> void:
	if _dragging_note == null:
		return
	var world_pos: Vector2 = get_canvas_transform().affine_inverse() * screen_pos
	var raw_ms: float = _current_ms + (_targets_node.position.y - world_pos.y) / PX_PER_MS
	var snapped_ms: float = clampf(_snap_to_grid(raw_ms), 0.0, _audio_length_ms)
	var new_action: String = _lane_from_world_x(world_pos.x)
	if new_action.is_empty():
		new_action = _dragging_note.action

	var lane_changed: bool = new_action != _dragging_note.action
	_dragging_note.time_ms = snapped_ms
	_drag_started = true

	if lane_changed:
		_dragging_note.action = new_action
		if _arrow_map.has(_dragging_note):
			var old_arrow = _arrow_map[_dragging_note]
			if is_instance_valid(old_arrow):
				old_arrow.queue_free()
			_arrow_map.erase(_dragging_note)
		_arrow_map[_dragging_note] = _create_arrow(_dragging_note)
	elif _arrow_map.has(_dragging_note):
		var arrow = _arrow_map[_dragging_note]
		if is_instance_valid(arrow):
			arrow.position.y = -snapped_ms * PX_PER_MS / _notes_node.scale.y


func _find_note_near_mouse(screen_pos: Vector2) -> NoteData:
	var world_pos: Vector2 = get_canvas_transform().affine_inverse() * screen_pos
	var action: String = _lane_from_world_x(world_pos.x)
	if action.is_empty():
		return null
	var raw_ms: float = _current_ms + (_targets_node.position.y - world_pos.y) / PX_PER_MS
	var best: NoteData = null
	var best_dist: float = SELECT_THRESHOLD_MS
	for n in _chart_data.notes:
		if n.action != action:
			continue
		var d: float = absf(n.time_ms - raw_ms)
		if d < best_dist:
			best_dist = d
			best = n
	return best


func _delete_note_at_mouse(screen_pos: Vector2) -> void:
	var world_pos: Vector2 = get_canvas_transform().affine_inverse() * screen_pos
	var action: String = _lane_from_world_x(world_pos.x)
	var raw_ms: float = _current_ms + (_targets_node.position.y - world_pos.y) / PX_PER_MS
	var best_idx: int = -1
	var best_dist: float = SELECT_THRESHOLD_MS
	for i in range(_chart_data.notes.size()):
		var n: NoteData = _chart_data.notes[i]
		if not action.is_empty() and n.action != action:
			continue
		var d: float = absf(n.time_ms - raw_ms)
		if d < best_dist:
			best_dist = d
			best_idx = i
	if best_idx >= 0:
		var note: NoteData = _chart_data.notes[best_idx]
		if _arrow_map.has(note) and is_instance_valid(_arrow_map[note]):
			_arrow_map[note].queue_free()
		_arrow_map.erase(note)
		_chart_data.notes.remove_at(best_idx)


func _lane_from_world_x(world_x: float) -> String:
	var best: String = ""
	var best_dist: float = LANE_CLICK_THRESHOLD_PX
	for action in LANE_ACTIONS:
		var lane_world_x: float = _notes_node.position.x + _lane_x[action] * _notes_node.scale.x
		var d: float = absf(world_x - lane_world_x)
		if d < best_dist:
			best_dist = d
			best = action
	return best


func _snap_to_grid(ms: float) -> float:
	if _chart_data.phases.is_empty():
		return ms
	var phase_idx: int = _chart_data.get_phase_at(ms)
	var phase: ChartLoader.PhaseData = _chart_data.phases[phase_idx]
	var beat_ms: float = (60.0 / phase.bpm) * 1000.0
	var subdiv_ms: float = beat_ms / float(_subdivision)
	return round(ms / subdiv_ms) * subdiv_ms


func _create_arrow(note: NoteData) -> NoteArrow:
	var arrow: NoteArrow = ARROW_SCENE.instantiate() as NoteArrow
	arrow.direction = ACTION_TO_DIRECTION[note.action]
	var local_y: float = -note.time_ms * PX_PER_MS / _notes_node.scale.y
	arrow.position = Vector2(_lane_x[note.action], local_y)
	_notes_node.add_child(arrow)
	arrow.set_process(false)
	arrow.set_physics_process(false)
	return arrow


func _rebuild_arrows() -> void:
	for arrow in _arrow_map.values():
		if is_instance_valid(arrow):
			arrow.queue_free()
	_arrow_map.clear()
	for note in _chart_data.notes:
		_arrow_map[note] = _create_arrow(note)


func _on_load_audio_pressed() -> void:
	_file_dialog_audio.popup_centered(Vector2i(800, 500))


func _on_audio_file_selected(path: String) -> void:
	var stream = load(path)
	if stream is AudioStream:
		_audio.stream = stream
		_chart_data.phases[0].audio_path = path
		_recalculate_audio_length()
		_current_ms = 0.0
		_toggle_play(false)


func _on_load_audio2_pressed() -> void:
	_file_dialog_audio2.popup_centered(Vector2i(800, 500))


func _on_audio2_file_selected(path: String) -> void:
	var stream = load(path)
	if stream is AudioStream:
		_audio2.stream = stream
		if _chart_data.phases.size() >= 2:
			_chart_data.phases[1].audio_path = path
		_recalculate_audio_length()


func _recalculate_audio_length() -> void:
	if _chart_data.phases.size() >= 2 and _audio2.stream != null:
		_audio_length_ms = _chart_data.phases[1].start_ms + _audio2.stream.get_length() * 1000.0
	elif _audio.stream != null:
		_audio_length_ms = _audio.stream.get_length() * 1000.0
	else:
		_audio_length_ms = 1000.0


func _on_set_phase2_start() -> void:
	if _chart_data.phases.size() < 2:
		var p2 := ChartLoader.PhaseData.new()
		p2.bpm = _bpm2_spin.value
		p2.start_ms = _current_ms
		_chart_data.phases.append(p2)
	else:
		_chart_data.phases[1].start_ms = _current_ms
		_chart_data.phases[1].bpm = _bpm2_spin.value
	_phase2_start_label.text = "@%s" % _format_time(_current_ms)
	_recalculate_audio_length()
	print("[EDITOR] Phase 2 start: %s | BPM: %.1f" % [_format_time(_current_ms), _bpm2_spin.value])


func _on_load_chart_pressed() -> void:
	_file_dialog_load.popup_centered(Vector2i(800, 500))


func _on_chart_file_selected(path: String) -> void:
	_chart_data = ChartLoader.load_json(path)
	_save_path = path

	if _chart_data.phases.is_empty():
		var p1 := ChartLoader.PhaseData.new()
		_chart_data.phases.append(p1)

	_bpm_spin.value = _chart_data.phases[0].bpm
	_title_edit.text = _chart_data.title

	if _chart_data.phases.size() >= 2:
		_bpm2_spin.value = _chart_data.phases[1].bpm
		_phase2_start_label.text = "@%s" % _format_time(_chart_data.phases[1].start_ms)
	else:
		_bpm2_spin.value = 120.0
		_phase2_start_label.text = "@—"

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
	_chart_data.title = _title_edit.text
	ChartLoader.save_json(path, _chart_data)
	print("[EDITOR] Guardado: %s (%d notas)" % [path, _chart_data.notes.size()])


func _toggle_play(play: bool) -> void:
	_is_playing = play
	if play:
		_current_editor_phase = _chart_data.get_phase_at(_current_ms)
		var spd: float = SPEED_OPTIONS[_speed_index]
		_audio.pitch_scale = spd
		_audio2.pitch_scale = spd
		if _current_editor_phase == 0 and _audio.stream != null:
			_audio.play(_current_ms / 1000.0)
		elif _current_editor_phase == 1 and _audio2.stream != null:
			var p2_start: float = _chart_data.phases[1].start_ms
			_audio2.play((_current_ms - p2_start) / 1000.0)
	else:
		_audio.stop()
		_audio2.stop()


func _apply_speed() -> void:
	var spd: float = SPEED_OPTIONS[_speed_index]
	_audio.pitch_scale = spd
	_audio2.pitch_scale = spd
	if _is_playing and _audio.stream != null and _current_editor_phase == 0:
		_audio.play(_current_ms / 1000.0)
	elif _is_playing and _audio2.stream != null and _current_editor_phase == 1:
		_audio2.play((_current_ms - _chart_data.phases[1].start_ms) / 1000.0)


func _seek(ms: float) -> void:
	_current_ms = clampf(ms, 0.0, _audio_length_ms)
	if _is_playing:
		_toggle_play(true)


func _place_note_at(action: String, ms: float) -> void:
	for n in _chart_data.notes:
		if absf(n.time_ms - ms) < 1.0 and n.action == action:
			return
	var note := NoteData.new()
	note.time_ms = ms
	note.action = action
	_chart_data.notes.append(note)
	_chart_data.notes.sort_custom(func(a: NoteData, b: NoteData) -> bool: return a.time_ms < b.time_ms)
	_arrow_map[note] = _create_arrow(note)
	print("[EDITOR] + %s @ %s" % [LANE_LABELS[action], _format_time(ms)])


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
