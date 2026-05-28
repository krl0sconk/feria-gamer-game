class_name RebindRow
extends HBoxContainer

signal rebind_requested(row: RebindRow)
signal joy_rebind_requested(row: RebindRow)
signal reset_requested(row: RebindRow)

@export var action_name: String = ""

@onready var _key_button: Button = %KeyButton
@onready var _joy_button: Button = %JoyButton
@onready var _reset_button: Button = %ResetButton

var _current_keycode: int = 0
var _current_joy: Dictionary = {}


func _ready() -> void:
	_key_button.pressed.connect(func(): rebind_requested.emit(self))
	_joy_button.pressed.connect(func(): joy_rebind_requested.emit(self))
	_reset_button.pressed.connect(func(): reset_requested.emit(self))


func set_keycode(keycode: int) -> void:
	_current_keycode = keycode
	_key_button.text = ControlsSettings.key_display(keycode)


func set_joy_binding(joy: Dictionary) -> void:
	_current_joy = joy.duplicate()
	_joy_button.text = ControlsSettings.joy_display(_current_joy)


func get_keycode() -> int:
	return _current_keycode


func get_joy_binding() -> Dictionary:
	return _current_joy.duplicate()


func set_listening_keyboard(active: bool) -> void:
	if active:
		_key_button.text = "..."
		_key_button.release_focus()
	else:
		_key_button.text = ControlsSettings.key_display(_current_keycode)


func set_listening_joy(active: bool) -> void:
	if active:
		_joy_button.text = "..."
		_joy_button.release_focus()
	else:
		_joy_button.text = ControlsSettings.joy_display(_current_joy)
