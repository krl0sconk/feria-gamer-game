extends Control

const MAIN_MENU_SCENE := "res://scenes/menu/main_menu.tscn"

@onready var _video: VideoStreamPlayer = $VideoStreamPlayer

var _leaving := false


func _ready() -> void:
	_video.finished.connect(_on_video_finished)
	_video.play()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_accept"):
		_go_to_menu()
		return
	if event is InputEventMouseButton and event.pressed:
		_go_to_menu()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_go_to_menu()


func _on_video_finished() -> void:
	_go_to_menu()


func _go_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	if _video.is_playing():
		_video.stop()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
