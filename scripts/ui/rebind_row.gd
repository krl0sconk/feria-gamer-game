class_name RebindRow
extends HBoxContainer

signal rebind_requested(row: RebindRow)
signal reset_requested(row: RebindRow)

@export var action_name: String = ""

@onready var _key_button: Button = %KeyButton
@onready var _reset_button: Button = %ResetButton

var _current_keycode: int = 0


func _ready() -> void:
	_key_button.pressed.connect(func(): rebind_requested.emit(self))
	_reset_button.pressed.connect(func(): reset_requested.emit(self))


func set_keycode(keycode: int) -> void:
	_current_keycode = keycode
	_key_button.text = ControlsSettings.key_display(keycode)


func get_keycode() -> int:
	return _current_keycode


func set_listening(active: bool) -> void:
	if active:
		_key_button.text = "..."
		_key_button.release_focus()
	else:
		_key_button.text = ControlsSettings.key_display(_current_keycode)
