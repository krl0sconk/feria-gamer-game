# Pantalla de victoria tras una batalla rítmica.
#
# Flujo:
#  - `Battle` detecta victoria → setea `Gamemanager.pending_dialogue_result = "win"`
#    y cambia a `WinScreen.tscn`.
#  - Esta pantalla muestra un mensaje + botón "Continuar".
#  - "Continuar" → `change_scene_to_file(Gamemanager.return_scene_path)` → el
#    Map reanuda el diálogo de victoria del NPC correspondiente.
#
# Responsabilidad única: vista de "ganaste" + routear al Map.
class_name WinScreen
extends Control

@export_file("*.tscn") var fallback_scene_path: String = "res://scenes/map/map.tscn"
@export var continue_button_path: NodePath = NodePath("Panel/VBox/ContinueButton")
@export var sfx_player_path: NodePath = NodePath("SfxPlayer")


func _ready() -> void:
	var btn := get_node_or_null(continue_button_path) as Button
	if btn != null:
		btn.pressed.connect(_on_continue_pressed)
	else:
		push_warning("WinScreen: no se encontró el botón en '%s'." % str(continue_button_path))
	var sfx := get_node_or_null(sfx_player_path) as AudioStreamPlayer
	if sfx != null and sfx.stream != null:
		sfx.play()


func _on_continue_pressed() -> void:
	var target: String = Gamemanager.return_scene_path
	if target.is_empty():
		target = fallback_scene_path
	get_tree().change_scene_to_file(target)
