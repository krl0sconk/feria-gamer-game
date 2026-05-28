extends Control

const PAUSE_MENU_SCENE_PATH := "res://scenes/ui/pause_menu.tscn"

@onready var _button: Button = $Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _button.pressed.is_connected(_on_pause_pressed):
		_button.pressed.connect(_on_pause_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.is_echo()):
		return
	if event.keycode == KEY_ESCAPE or event.is_action_pressed("ui_cancel"):
		_toggle_pause_menu()
		get_viewport().set_input_as_handled()


func _on_pause_pressed() -> void:
	_toggle_pause_menu()


func _toggle_pause_menu() -> void:
	var tree := get_tree()
	if tree == null:
		push_error("PauseButton: no SceneTree disponible")
		return
	var host := tree.current_scene
	if host == null:
		host = tree.root
	var ui_host := host.get_node_or_null("CanvasLayer")
	if ui_host == null:
		ui_host = host
	var existing := ui_host.get_node_or_null("PauseMenu")
	if existing != null:
		tree.paused = false
		existing.queue_free()
		return
	var scene := load(PAUSE_MENU_SCENE_PATH) as PackedScene
	if scene == null:
		push_error("PauseButton: no se pudo cargar %s" % PAUSE_MENU_SCENE_PATH)
		return
	var menu := scene.instantiate() as Control
	menu.name = "PauseMenu"
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_host.add_child(menu)
	tree.paused = true
