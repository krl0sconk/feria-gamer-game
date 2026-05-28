class_name ControlBinding
extends RefCounted

const TYPE_KEY := "key"
const TYPE_JOY_BUTTON := "joy_button"
const TYPE_JOY_AXIS := "joy_axis"


static func from_input_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey and event.pressed and not event.echo:
		return {"type": TYPE_KEY, "keycode": event.physical_keycode}
	if event is InputEventJoypadButton and event.pressed:
		return {
			"type": TYPE_JOY_BUTTON,
			"button": event.button_index,
			"device": event.device,
		}
	if event is InputEventJoypadMotion:
		if absf(event.axis_value) < 0.5:
			return {}
		return {
			"type": TYPE_JOY_AXIS,
			"axis": event.axis,
			"value": 1.0 if event.axis_value >= 0.0 else -1.0,
			"device": event.device,
		}
	return {}


static func to_input_event(binding: Dictionary) -> InputEvent:
	if binding.is_empty():
		return null
	match str(binding.get("type", "")):
		TYPE_KEY:
			var key_ev := InputEventKey.new()
			key_ev.physical_keycode = int(binding.get("keycode", 0))
			return key_ev
		TYPE_JOY_BUTTON:
			var btn_ev := InputEventJoypadButton.new()
			btn_ev.button_index = int(binding.get("button", 0))
			btn_ev.device = int(binding.get("device", -1))
			return btn_ev
		TYPE_JOY_AXIS:
			var axis_ev := InputEventJoypadMotion.new()
			axis_ev.axis = int(binding.get("axis", 0))
			axis_ev.axis_value = float(binding.get("value", 0.0))
			axis_ev.device = int(binding.get("device", -1))
			return axis_ev
	return null


static func display(binding: Dictionary) -> String:
	if binding.is_empty():
		return "---"
	match str(binding.get("type", "")):
		TYPE_KEY:
			return OS.get_keycode_string(int(binding.get("keycode", 0)))
		TYPE_JOY_BUTTON:
			return _joy_button_name(int(binding.get("button", 0)))
		TYPE_JOY_AXIS:
			return "%s %s" % [_joy_axis_name(int(binding.get("axis", 0))), "+" if float(binding.get("value", 0.0)) >= 0.0 else "-"]
	return "---"


static func _joy_button_name(button_index: int) -> String:
	match button_index:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_BACK: return "Select"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_DPAD_UP: return "D-Pad Up"
		JOY_BUTTON_DPAD_DOWN: return "D-Pad Down"
		JOY_BUTTON_DPAD_LEFT: return "D-Pad Left"
		JOY_BUTTON_DPAD_RIGHT: return "D-Pad Right"
		_: return "Btn %d" % button_index


static func _joy_axis_name(axis: int) -> String:
	match axis:
		JOY_AXIS_LEFT_X: return "Stick X"
		JOY_AXIS_LEFT_Y: return "Stick Y"
		JOY_AXIS_RIGHT_X: return "R-Stick X"
		JOY_AXIS_RIGHT_Y: return "R-Stick Y"
		JOY_AXIS_TRIGGER_LEFT: return "L2"
		JOY_AXIS_TRIGGER_RIGHT: return "R2"
		_: return "Axis %d" % axis
