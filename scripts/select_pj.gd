extends Control


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func selectedskin(skinname) -> void:
	Gamemanager.selectedskin = skinname
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")

func _on_button_pressed() -> void:
	selectedskin("idle (1)")
	

func _on_button_6_pressed() -> void:
	selectedskin("idle pj2")
