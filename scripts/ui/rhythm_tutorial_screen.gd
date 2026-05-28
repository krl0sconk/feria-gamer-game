## Pantalla intermedia entre diálogo e interactuable y la batalla rítmica.
## Consume `Gamemanager.pending_battle_scene_path` al confirmar.
extends Control

const DEFAULT_PAGES_PATH := "res://assets/data/guitar_rhythm_tutorial.json"
const FALLBACK_BATTLE := "res://scenes/rhythm/tutorial.tscn"
const FALLBACK_RETURN := "res://scenes/map/room.tscn"

@export_file("*.json") var pages_json_path: String = DEFAULT_PAGES_PATH
@export_file("*.tscn") var fallback_battle_scene_path: String = FALLBACK_BATTLE
@export_file("*.tscn") var fallback_return_scene_path: String = FALLBACK_RETURN

@onready var _title: Label = %ScreenTitle
@onready var _page_title: Label = %PageTitle
@onready var _body: Label = %BodyLabel
@onready var _page_counter: Label = %PageCounter
@onready var _icons_row: HBoxContainer = %IconsRow
@onready var _prev_button: Button = %PrevButton
@onready var _next_button: Button = %NextButton
@onready var _hint: Label = %HintLabel

var _pages: Array = []
var _page_index: int = 0


func _ready() -> void:
	_load_pages()
	_prev_button.pressed.connect(_on_prev_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_show_page(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_mark_input_handled()
		_go_back_to_map()
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("Interact"):
		_mark_input_handled()
		if _page_index >= _pages.size() - 1:
			_start_battle()
		else:
			_show_page(_page_index + 1)
		return
	if event.is_action_pressed("ui_left"):
		_on_prev_pressed()
		_mark_input_handled()
	elif event.is_action_pressed("ui_right"):
		_on_next_pressed()
		_mark_input_handled()


func _mark_input_handled() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _load_pages() -> void:
	_pages.clear()
	var path := pages_json_path if not pages_json_path.is_empty() else DEFAULT_PAGES_PATH
	if not FileAccess.file_exists(path):
		push_warning("RhythmTutorialScreen: no se encontró %s" % path)
		_pages = [_fallback_page()]
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("RhythmTutorialScreen: JSON inválido en %s" % path)
		_pages = [_fallback_page()]
		return
	var data: Dictionary = parsed
	if _title != null:
		_title.text = str(data.get("screen_title", "Tutorial de ritmo"))
	var raw_pages: Variant = data.get("pages", [])
	if typeof(raw_pages) != TYPE_ARRAY or (raw_pages as Array).is_empty():
		_pages = [_fallback_page()]
		return
	_pages = raw_pages


func _fallback_page() -> Dictionary:
	return {
		"title": "Controles",
		"body": "Pulsa la tecla o el botón del mando cuando las flechas lleguen abajo:\n\n{left}  {down}  {up}  {right}",
	}


func _show_page(index: int) -> void:
	if _pages.is_empty():
		return
	_page_index = clampi(index, 0, _pages.size() - 1)
	var page: Dictionary = _pages[_page_index]
	_page_title.text = str(page.get("title", ""))
	_body.text = _substitute_keys(str(page.get("body", "")))
	_page_counter.text = "%d / %d" % [_page_index + 1, _pages.size()]
	_populate_icons(page.get("icons", []))
	_prev_button.visible = _page_index > 0
	var is_last := _page_index >= _pages.size() - 1
	_next_button.text = "A la batalla" if is_last else "Siguiente"
	_hint.text = "[Enter / E / A] %s" % ("empezar" if is_last else "siguiente")


func _populate_icons(icons: Variant) -> void:
	for child in _icons_row.get_children():
		child.queue_free()
	if typeof(icons) != TYPE_ARRAY:
		return
	for item in icons as Array:
		var tex_path := str(item).strip_edges()
		if tex_path.is_empty():
			continue
		var tex := load(tex_path) as Texture2D
		if tex == null:
			continue
		var rect := TextureRect.new()
		rect.custom_minimum_size = Vector2(72, 72)
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture = tex
		_icons_row.add_child(rect)


func _substitute_keys(text: String) -> String:
	return text.replace("{left}", _action_binding_label("note_left")) \
		.replace("{down}", _action_binding_label("note_down")) \
		.replace("{up}", _action_binding_label("note_up")) \
		.replace("{right}", _action_binding_label("note_right"))


func _action_binding_label(action: String) -> String:
	var defaults := ControlsSettings.default_bindings()
	var entry: Dictionary = ControlsSettings.load_bindings().get(action, defaults.get(action, {}))
	var key_label := ControlsSettings.key_display(int(entry.get("key", 0)))
	var joy: Variant = entry.get("joy", {})
	var joy_label := ""
	if typeof(joy) == TYPE_DICTIONARY:
		joy_label = ControlsSettings.joy_display(joy as Dictionary)
	if joy_label.is_empty() or joy_label == "---":
		return key_label if not key_label.is_empty() else "?"
	return "%s  |  %s" % [key_label, joy_label]


func _on_prev_pressed() -> void:
	if _page_index <= 0:
		return
	_show_page(_page_index - 1)


func _on_next_pressed() -> void:
	if _page_index >= _pages.size() - 1:
		_start_battle()
		return
	_show_page(_page_index + 1)


func _start_battle() -> void:
	var battle_path := Gamemanager.consume_pending_battle_scene_path()
	if battle_path.is_empty():
		battle_path = fallback_battle_scene_path
	if battle_path.is_empty():
		push_error("RhythmTutorialScreen: no hay escena de batalla pendiente.")
		_go_back_to_map()
		return
	get_tree().call_deferred("change_scene_to_file", battle_path)


func _go_back_to_map() -> void:
	var target := Gamemanager.return_scene_path
	if target.is_empty():
		target = fallback_return_scene_path
	Gamemanager.consume_pending_battle_scene_path()
	get_tree().call_deferred("change_scene_to_file", target)
