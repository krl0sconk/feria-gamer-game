extends Control

const MAIN_MENU_PATH := "res://scenes/menu/main_menu.tscn"
const FALLBACK_MAP_PATH := "res://scenes/map/map.tscn"

@onready var _resume: Button = $CenterContainer/Panel/VBox/Resume
@onready var _exit: Button = $CenterContainer/Panel/VBox/Exit

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not _resume.pressed.is_connected(_on_resume_pressed):
		_resume.pressed.connect(_on_resume_pressed)
	if not _exit.pressed.is_connected(_on_exit_pressed):
		_exit.pressed.connect(_on_exit_pressed)
	_update_exit_label()
	call_deferred("_center_panel")


func _center_panel() -> void:
	var panel := get_node_or_null("CenterContainer/Panel") as Control
	if panel == null:
		return
	var size := get_viewport_rect().size
	panel.position = Vector2((size.x - panel.size.x) * 0.5, (size.y - panel.size.y) * 0.5)


func _update_exit_label() -> void:
	if _is_battle_context():
		_exit.text = "Abandonar batalla"
	else:
		_exit.text = "Salir al menú"


func _is_battle_context() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var path := scene.scene_file_path
	if path.contains("/ui/rhythm_tutorial"):
		return true
	if not path.contains("/rhythm/"):
		return false
	return not path.contains("win_screen") and not path.contains("lose_screen")


func _on_resume_pressed() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false
	queue_free()


func _on_exit_pressed() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false

	if _is_battle_context():
		var target := Gamemanager.return_scene_path
		if target.is_empty():
			target = FALLBACK_MAP_PATH
		Gamemanager.prepare_abort_from_battle()
		tree.call_deferred("change_scene_to_file", target)
		return

	var sm := get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("save_slot"):
		var slot_idx := 0
		if sm.has_method("get_active_slot"):
			slot_idx = int(sm.get_active_slot())
		if slot_idx > 0:
			sm.save_slot(slot_idx, {})
	tree.call_deferred("change_scene_to_file", MAIN_MENU_PATH)
