extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
	pass # Replace with function body.


func selectedskin(skinname) -> void:
	Gamemanager.selectedskin = skinname
	get_tree().change_scene_to_file("res://scenes/map/Map.tscn")

func _on_button_pressed() -> void:
	selectedskin("idle (1)")
	

func _on_button_6_pressed() -> void:
	selectedskin("idle pj2")
