extends Control

const SKINS := ["idle (1)", "idle pj2"]

@onready var _grid: GridContainer = $GridContainer
@onready var _back: Button = $BoxContainer/Back
@onready var _save_manager: Node = get_node_or_null("/root/SaveManager")


func _ready() -> void:
	if not _back.pressed.is_connected(_on_back_pressed):
		_back.pressed.connect(_on_back_pressed)
	var buttons: Array[Button] = []
	for child in _grid.get_children():
		if child is Button:
			buttons.append(child)
	for i in range(buttons.size()):
		buttons[i].pressed.connect(_on_skin_button_pressed.bind(i))
		if i < SKINS.size():
			buttons[i].disabled = false
		else:
			buttons[i].disabled = true
			buttons[i].text = "Bloqueado"
			buttons[i].tooltip_text = "Solo hay 2 skins disponibles de momento"


func _on_back_pressed() -> void:
	var tree := get_tree()
	if tree == null:
		push_error("select_pj: no SceneTree disponible para volver al menú")
		return
	tree.call_deferred("change_scene_to_file", "res://scenes/menu/main_menu.tscn")


func selectedskin(skinname: String) -> void:
	Gamemanager.selectedskin = skinname
	var tree := get_tree()
	if tree == null:
		push_error("select_pj: no SceneTree disponible para cambiar a room.tscn")
		return
	tree.call_deferred("change_scene_to_file", "res://scenes/map/room.tscn")
	await tree.process_frame
	await tree.process_frame
	if _save_manager != null and _save_manager.has_method("get_active_slot"):
		var active_slot := int(_save_manager.get_active_slot())
		if active_slot > 0 and _save_manager.has_method("save_slot"):
			var ok: bool = bool(_save_manager.save_slot(active_slot))
			print("select_pj: save_slot result = %s" % str(ok))

func _on_skin_button_pressed(index: int) -> void:
	if index < 0 or index >= SKINS.size():
		return
	selectedskin(SKINS[index])
