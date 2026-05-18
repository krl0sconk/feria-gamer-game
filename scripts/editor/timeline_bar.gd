class_name TimelineBar
extends Control

## Barra de navegación horizontal del editor de charts.
## Click o drag para mover el playhead a esa posición.

const BG_COLOR := Color(0.08, 0.08, 0.10, 0.94)
const BORDER_COLOR := Color(0.50, 0.50, 0.60, 0.55)
const MEASURE_COLOR := Color(0.35, 0.35, 0.48, 0.55)
const NOTE_COLOR := Color(0.92, 0.86, 0.22, 0.88)
const PHASE_COLOR := Color(1.00, 0.45, 0.10, 0.92)
const PLAYHEAD_COLOR := Color(1.00, 1.00, 1.00, 0.96)

var _chart_editor: ChartEditor
var _dragging: bool = false


func _ready() -> void:
	# ChartEditor → EditorUI (CanvasLayer) → TimelineBar
	_chart_editor = get_parent().get_parent() as ChartEditor
	mouse_default_cursor_shape = Control.CURSOR_HSIZE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if _chart_editor == null or w <= 0.0:
		return

	var total_ms: float = maxf(_chart_editor._audio_length_ms, 1.0)

	draw_rect(Rect2(0.0, 0.0, w, h), BG_COLOR)

	# Líneas de compás (cada 4 tiempos por fase)
	var data: ChartLoader.ChartData = _chart_editor._chart_data
	for i in range(data.phases.size()):
		var phase: ChartLoader.PhaseData = data.phases[i]
		var phase_end: float = total_ms if i + 1 >= data.phases.size() else data.phases[i + 1].start_ms
		var measure_ms: float = (60.0 / phase.bpm) * 4000.0
		var t: float = phase.start_ms
		while t <= phase_end:
			var x: float = (t / total_ms) * w
			draw_line(Vector2(x, h * 0.5), Vector2(x, h), MEASURE_COLOR, 1.0)
			t += measure_ms

	# Marcas de notas
	for note: NoteData in data.notes:
		var x: float = (note.time_ms / total_ms) * w
		draw_rect(Rect2(x - 1.0, h * 0.12, 2.0, h * 0.76), NOTE_COLOR)

	# Límite de fase 2
	if data.phases.size() >= 2:
		var px: float = (data.phases[1].start_ms / total_ms) * w
		draw_rect(Rect2(px - 1.0, 0.0, 2.0, h), PHASE_COLOR)

	# Playhead
	var hx: float = (_chart_editor._current_ms / total_ms) * w
	draw_rect(Rect2(hx - 1.0, 0.0, 2.0, h), PLAYHEAD_COLOR)

	draw_rect(Rect2(0.0, 0.0, w, 1.0), BORDER_COLOR)
	draw_rect(Rect2(0.0, h - 1.0, w, 1.0), BORDER_COLOR)


func _gui_input(event: InputEvent) -> void:
	if _chart_editor == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_seek_to(event.position.x)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_seek_to(event.position.x)
		accept_event()


func _seek_to(local_x: float) -> void:
	var ratio: float = clampf(local_x / size.x, 0.0, 1.0)
	_chart_editor._seek(ratio * _chart_editor._audio_length_ms)
