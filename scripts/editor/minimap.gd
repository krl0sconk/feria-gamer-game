class_name Minimap
extends Control

## Minimap vertical del editor de charts. Muestra todas las notas,
## el viewport actual, playhead y permite seleccionar/navegar.

const BG_COLOR := Color(0.08, 0.08, 0.10, 0.96)
const LANE_DIVIDER_COLOR := Color(0.25, 0.25, 0.30, 0.5)
const NOTE_COLOR := Color(0.92, 0.86, 0.22, 0.9)
const FAKE_NOTE_COLOR := Color(0.7, 0.3, 0.9, 0.9)
const PLAYHEAD_COLOR := Color(1.0, 1.0, 1.0, 0.95)
const VIEWPORT_BG := Color(0.15, 0.15, 0.22, 0.35)
const VIEWPORT_BORDER := Color(0.5, 0.5, 0.65, 0.6)
const SELECTION_COLOR := Color(1.0, 0.55, 0.1, 1.0)
const PHASE_COLOR := Color(1.0, 0.45, 0.1, 0.92)
const LABEL_COLOR := Color(0.6, 0.6, 0.7, 0.8)

const LANE_ACTIONS: Array[String] = ["note_left", "note_down", "note_up", "note_right"]
const LANE_LABELS: Array[String] = ["←", "↓", "↑", "→"]

var _editor: ChartEditor
var _dragging: bool = false
var _box_selecting: bool = false
var _box_start_ms: float = 0.0
var _box_end_ms: float = 0.0

const LABEL_WIDTH: float = 18.0
const NOTE_HEIGHT: float = 4.0
const NOTE_MIN_WIDTH: float = 6.0


func _ready() -> void:
	# Minimap → MinimapPanel → EditorUI (CanvasLayer) → ChartEditor
	_editor = get_parent().get_parent().get_parent() as ChartEditor
	mouse_default_cursor_shape = Control.CURSOR_VSIZE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _editor == null:
		return

	var w: float = size.x
	var h: float = size.y
	if w <= 0 or h <= 0:
		return
	var total_ms: float = maxf(_editor._audio_length_ms, 1.0)

	draw_rect(Rect2(0, 0, w, h), BG_COLOR)

	var lane_area_w: float = w - LABEL_WIDTH
	var lane_w: float = lane_area_w / 4.0

	# Etiquetas de carril
	for i in range(4):
		var lx: float = LABEL_WIDTH + lane_w * i + lane_w * 0.5
		draw_string(ThemeDB.fallback_font, Vector2(2, LABEL_WIDTH + 12), LANE_LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, -1, 12, LABEL_COLOR)

	# Divisores de carril
	for i in range(1, 4):
		var dx: float = LABEL_WIDTH + lane_w * i
		draw_line(Vector2(dx, 0), Vector2(dx, h), LANE_DIVIDER_COLOR, 1.0)

	# Límite de fase 2
	var data: ChartLoader.ChartData = _editor._chart_data
	if data.phases.size() >= 2:
		var py: float = _ms_to_y(data.phases[1].start_ms, total_ms, h)
		draw_rect(Rect2(LABEL_WIDTH, py, lane_area_w, 2.0), PHASE_COLOR)

	# Notas
	for note: NoteData in data.notes:
		var ny: float = _ms_to_y(note.time_ms, total_ms, h)
		var lane_idx: int = LANE_ACTIONS.find(note.action)
		if lane_idx < 0:
			continue
		var nx: float = LABEL_WIDTH + lane_w * lane_idx + 2.0
		var nw: float = lane_w - 4.0
		var color := FAKE_NOTE_COLOR if note.is_fake else NOTE_COLOR
		var is_selected: bool = _editor._selected_notes.has(note)
		draw_rect(Rect2(nx, ny, nw, NOTE_HEIGHT), color)
		if is_selected:
			draw_rect(Rect2(nx - 1, ny - 1, nw + 2, NOTE_HEIGHT + 2), SELECTION_COLOR, false, 1.5)

	# Viewport rectangle
	if total_ms > 0:
		var visible_ms: float = get_viewport_rect().size.y / _editor.PX_PER_MS
		var vp_top_y: float = _ms_to_y(_editor._current_ms, total_ms, h)
		var vp_bot_y: float = _ms_to_y(_editor._current_ms - visible_ms, total_ms, h)
		var vp_h: float = absf(vp_bot_y - vp_top_y)
		draw_rect(Rect2(LABEL_WIDTH, minf(vp_top_y, vp_bot_y), lane_area_w, vp_h), VIEWPORT_BG)
		draw_rect(Rect2(LABEL_WIDTH, minf(vp_top_y, vp_bot_y), lane_area_w, 1.0), VIEWPORT_BORDER)
		draw_rect(Rect2(LABEL_WIDTH, maxf(vp_top_y, vp_bot_y) - 1.0, lane_area_w, 1.0), VIEWPORT_BORDER)

	# Playhead
	var hy: float = _ms_to_y(_editor._current_ms, total_ms, h)
	draw_rect(Rect2(LABEL_WIDTH, hy, lane_area_w, 2.0), PLAYHEAD_COLOR)

	# Box select rectangle
	if _box_selecting:
		var y1: float = _ms_to_y(_box_start_ms, total_ms, h)
		var y2: float = _ms_to_y(_box_end_ms, total_ms, h)
		var top_y: float = minf(y1, y2)
		var bot_y: float = maxf(y1, y2)
		draw_rect(Rect2(LABEL_WIDTH, top_y, lane_area_w, bot_y - top_y), Color(0.3, 0.5, 1.0, 0.25))
		draw_rect(Rect2(LABEL_WIDTH, top_y, lane_area_w, 1.0), Color(0.4, 0.6, 1.0, 0.8))
		draw_rect(Rect2(LABEL_WIDTH, bot_y, lane_area_w, 1.0), Color(0.4, 0.6, 1.0, 0.8))


func _gui_input(event: InputEvent) -> void:
	if _editor == null:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				if event.shift_pressed:
					_box_selecting = true
					_box_start_ms = _y_to_ms(event.position.y)
					_box_end_ms = _box_start_ms
				else:
					var clicked_note: NoteData = _find_note_at(event.position)
					if clicked_note != null:
						_editor.select_note(clicked_note, false)
					else:
						_editor.clear_selection()
						_seek_to(event.position.y)
			else:
				if _box_selecting:
					_editor.select_notes_in_range(_box_start_ms, _box_end_ms)
					_box_selecting = false
				_dragging = false
			accept_event()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_editor._seek(_editor._current_ms - 200.0)
			accept_event()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_editor._seek(_editor._current_ms + 200.0)
			accept_event()
			return
	elif event is InputEventMouseMotion:
		if _dragging and not _box_selecting:
			_seek_to(event.position.y)
		elif _box_selecting:
			_box_end_ms = _y_to_ms(event.position.y)
		accept_event()


func _ms_to_y(ms: float, total_ms: float, h: float) -> float:
	var ratio: float = clampf(ms / total_ms, 0.0, 1.0)
	return ratio * h


func _y_to_ms(y: float) -> float:
	var total_ms: float = maxf(_editor._audio_length_ms, 1.0)
	var ratio: float = clampf(y / size.y, 0.0, 1.0)
	return ratio * total_ms


func _find_note_at(screen_pos: Vector2) -> NoteData:
	if _editor == null:
		return null
	var total_ms: float = maxf(_editor._audio_length_ms, 1.0)
	var lane_w: float = (size.x - LABEL_WIDTH) / 4.0
	var lane_idx: int = int((screen_pos.x - LABEL_WIDTH) / lane_w)
	if lane_idx < 0 or lane_idx > 3:
		return null
	var action: String = LANE_ACTIONS[lane_idx]
	var raw_ms: float = _y_to_ms(screen_pos.y)
	var best: NoteData = null
	var best_dist: float = 30.0 / _editor.PX_PER_MS
	for n: NoteData in _editor._chart_data.notes:
		if n.action != action:
			continue
		var d: float = absf(n.time_ms - raw_ms)
		if d < best_dist:
			best_dist = d
			best = n
	return best


func _seek_to(y: float) -> void:
	_editor._seek(_y_to_ms(y))
