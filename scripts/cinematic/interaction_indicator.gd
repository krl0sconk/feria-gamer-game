# Indicador flotante (! / ?) sobre NPCs o triggers con interacción pendiente.
@tool
class_name InteractionIndicator
extends Node2D

enum DisplayMode { AUTO, ON, OFF }

@export var mode: DisplayMode = DisplayMode.AUTO:
	set(value):
		mode = value
		_refresh_visibility()

@export var symbol: String = "!":
	set(value):
		symbol = value
		queue_redraw()

@export var bob_amplitude: float = 5.0
@export var bob_speed: float = 4.0
@export var vertical_offset: float = -52.0:
	set(value):
		vertical_offset = value
		_base_y = value
		position.y = value

@export var font_size: int = 22:
	set(value):
		font_size = value
		queue_redraw()

@export var tint: Color = Color(1.0, 0.92, 0.15, 1.0):
	set(value):
		tint = value
		queue_redraw()

@export var outline_color: Color = Color(0.08, 0.08, 0.08, 1.0):
	set(value):
		outline_color = value
		queue_redraw()

@export var show_in_editor: bool = true:
	set(value):
		show_in_editor = value
		_refresh_visibility()

var _base_y: float = -52.0
var _time: float = 0.0
var _host: Node = null


func _ready() -> void:
	_base_y = vertical_offset
	position.y = _base_y
	z_index = 10
	_host = get_parent()
	if Engine.is_editor_hint():
		set_process(true)
		_refresh_visibility()
		return

	set_process(true)
	if QuestManager.has_signal("quest_completed"):
		QuestManager.quest_completed.connect(_on_world_state_changed)
	_refresh_visibility()


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * bob_speed) * bob_amplitude
	if not Engine.is_editor_hint():
		_refresh_visibility()


func refresh() -> void:
	_refresh_visibility()


func _on_world_state_changed(_quest_id: String = "") -> void:
	_refresh_visibility()


func _refresh_visibility() -> void:
	var show := _should_be_visible()
	if visible != show:
		visible = show
	if show or Engine.is_editor_hint():
		queue_redraw()


func _should_be_visible() -> bool:
	match mode:
		DisplayMode.ON:
			return true
		DisplayMode.OFF:
			return false
		DisplayMode.AUTO:
			if Engine.is_editor_hint():
				return _editor_auto_visible()
			if _host != null and _host.has_method("should_show_indicator"):
				return bool(_host.call("should_show_indicator"))
			return false
	return false


func _editor_auto_visible() -> bool:
	if not show_in_editor:
		return false
	if _host != null and "show_indicator" in _host:
		return bool(_host.get("show_indicator"))
	return true


func _draw() -> void:
	if not visible and not (Engine.is_editor_hint() and show_in_editor and mode != DisplayMode.OFF):
		return

	var text := symbol if not symbol.is_empty() else "!"
	var font := _font()
	var draw_pos := Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5, font_size * 0.35)

	for ox in [-1, 0, 1]:
		for oy in [-1, 0, 1]:
			if ox == 0 and oy == 0:
				continue
			draw_string(font, draw_pos + Vector2(ox, oy), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_color)
	draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)


func _font() -> Font:
	var retro := load("res://assets/fonts/retro_bound.ttf") as Font
	if retro != null:
		return retro
	return ThemeDB.fallback_font
