extends Control

const SKINS := ["idle (1)", "idlepj2", "idlepj3", "idlepj4"]

const SKIN_DATA := {
	"idle (1)": {
		"frames": preload("res://assets/images/characters/pj1/pj1_battle.tres"),
		"display_name": "Personaje 1",
		"idle_anim": &"idle"
	},
	"idlepj2": {
		"frames": preload("res://assets/images/characters/pj2/pj2_battle.tres"),
		"display_name": "Personaje 2",
		"idle_anim": &"idle"
	},
	"idlepj3": {
		"frames": preload("res://assets/images/characters/pj2/pj2_battle.tres"),
		"display_name": "Personaje 3",
		"idle_anim": &"idle"
	},
	"idlepj4": {
		"frames": preload("res://assets/images/characters/pj4/pj4_battle.tres"),
		"display_name": "Personaje 4",
		"idle_anim": &"idle"
	}
}

@onready var _grid: GridContainer = $GridContainer
@onready var _back: Button = $Back
@onready var _preview_sprite: AnimatedSprite2D = $PreviewSprite
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
			buttons[i].mouse_entered.connect(_on_button_hovered.bind(i))
			buttons[i].focus_entered.connect(_on_button_focused.bind(i))
		else:
			buttons[i].disabled = true
			buttons[i].text = "Bloqueado"
			buttons[i].tooltip_text = "Solo hay 3 skins disponibles de momento"
	_update_preview(0)


func _update_preview(index: int) -> void:
	if index < 0 or index >= SKINS.size():
		return
	var skin_key: String = SKINS[index]
	var data: Dictionary = SKIN_DATA.get(skin_key, {})
	if data.is_empty():
		return
	_preview_sprite.sprite_frames = data["frames"] as SpriteFrames
	var anim_name: StringName = data["idle_anim"]
	if _preview_sprite.sprite_frames.has_animation(anim_name):
		_preview_sprite.play(anim_name)


func _on_button_hovered(index: int) -> void:
	_update_preview(index)


func _on_button_focused(index: int) -> void:
	_update_preview(index)


func _on_back_pressed() -> void:
	var tree := get_tree()
	if tree == null:
		push_error("select_pj: no SceneTree disponible para volver al menú")
		return
	tree.call_deferred("change_scene_to_file", "res://scenes/menu/save_slots.tscn")


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
