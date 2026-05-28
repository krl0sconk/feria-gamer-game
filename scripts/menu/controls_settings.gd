class_name ControlsSettings
extends RefCounted

const SETTINGS_PATH: String = "user://settings.cfg"

## Acciones remapeables agrupadas. Cada entrada: label (UI) + default (physical_keycode).
const ACTIONS: Dictionary = {
	"move_up":    {"label": "Mover arriba",      "default": KEY_UP},
	"move_down":  {"label": "Mover abajo",       "default": KEY_DOWN},
	"move_left":  {"label": "Mover izquierda",   "default": KEY_LEFT},
	"move_right": {"label": "Mover derecha",     "default": KEY_RIGHT},
	"Interact":   {"label": "Interactuar",       "default": KEY_E},
	"note_up":    {"label": "Nota arriba",       "default": KEY_J},
	"note_down":  {"label": "Nota abajo",        "default": KEY_F},
	"note_left":  {"label": "Nota izquierda",    "default": KEY_D},
	"note_right": {"label": "Nota derecha",      "default": KEY_K},
}

## Acciones de gameplay que también deben funcionar como navegación de UI.
## El binding del jugador para `Interact` se duplica en `ui_accept`, y los
## `move_*` en `ui_up`/`ui_down`/`ui_left`/`ui_right`, así Godot puede usar
## su navegación nativa de focus en menús (lose/win/pause/etc.) con las
## mismas teclas y joystick que el jugador escogió.
const ACTION_TO_UI: Dictionary = {
	"Interact":   "ui_accept",
	"move_up":    "ui_up",
	"move_down":  "ui_down",
	"move_left":  "ui_left",
	"move_right": "ui_right",
}

## Eventos que añadimos a cada acción ui_*. Necesitamos recordarlos para
## poder limpiarlos en cada `apply_bindings` y no acumular copias viejas
## de teclas/joys re-bindeados, sin tocar los defaults del project.godot.
static var _ui_mirror_events: Dictionary = {}


static func load_bindings() -> Dictionary:
	var bindings := _defaults()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return bindings
	for action in ACTIONS:
		bindings[action]["key"] = int(cfg.get_value("controls", action, bindings[action]["key"]))
		if cfg.has_section_key("controls_joy", action):
			var joy_raw: Variant = cfg.get_value("controls_joy", action)
			if typeof(joy_raw) == TYPE_STRING and not str(joy_raw).is_empty():
				var parsed: Variant = JSON.parse_string(str(joy_raw))
				if typeof(parsed) == TYPE_DICTIONARY:
					bindings[action]["joy"] = parsed
	return bindings


static func save_bindings(bindings: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	for action in bindings:
		var entry: Dictionary = bindings[action]
		cfg.set_value("controls", action, int(entry.get("key", ACTIONS[action]["default"])))
		var joy: Dictionary = entry.get("joy", {})
		if joy.is_empty():
			cfg.set_value("controls_joy", action, "")
		else:
			cfg.set_value("controls_joy", action, JSON.stringify(joy))
	cfg.save(SETTINGS_PATH)


static func apply_bindings(bindings: Dictionary) -> void:
	for action in bindings:
		if not InputMap.has_action(action):
			continue
		for ev in InputMap.action_get_events(action):
			InputMap.action_erase_event(action, ev)

		var entry: Dictionary = bindings[action]
		var key_ev := InputEventKey.new()
		key_ev.physical_keycode = int(entry.get("key", ACTIONS[action]["default"]))
		InputMap.action_add_event(action, key_ev)

		var joy: Dictionary = entry.get("joy", {})
		var joy_ev := ControlBinding.to_input_event(joy)
		if joy_ev != null:
			InputMap.action_add_event(action, joy_ev)

	_refresh_ui_mirrors()


## Espeja Interact/move_* en ui_accept/ui_*. Borra primero los eventos que
## sembramos en pasadas anteriores (los guarda `_ui_mirror_events`), así no
## se acumulan duplicados al re-bindear. Los defaults declarados en
## project.godot (Enter, Espacio, joy A, flechas, D-Pad, L-stick) se
## respetan porque sólo borramos lo que metimos nosotros.
static func _refresh_ui_mirrors() -> void:
	for game_action in ACTION_TO_UI.keys():
		var ui_action: String = ACTION_TO_UI[game_action]
		if not InputMap.has_action(ui_action):
			continue
		var prior: Array = _ui_mirror_events.get(ui_action, [])
		for ev in prior:
			if ev != null:
				InputMap.action_erase_event(ui_action, ev)
		_ui_mirror_events[ui_action] = []
		if not InputMap.has_action(game_action):
			continue
		var existing: Array = InputMap.action_get_events(ui_action)
		for ev in InputMap.action_get_events(game_action):
			if ev == null:
				continue
			var dup := false
			for ex in existing:
				if ex != null and ex.is_match(ev, true):
					dup = true
					break
			if dup:
				continue
			InputMap.action_add_event(ui_action, ev)
			(_ui_mirror_events[ui_action] as Array).append(ev)


static func key_display(physical_keycode: int) -> String:
	return OS.get_keycode_string(physical_keycode)


static func joy_display(joy: Dictionary) -> String:
	return ControlBinding.display(joy)


static func default_bindings() -> Dictionary:
	return _defaults()


static func default_joy_for(action: String) -> Dictionary:
	return _default_joy(action)


static func _defaults() -> Dictionary:
	var d: Dictionary = {}
	for action in ACTIONS:
		d[action] = {
			"key": ACTIONS[action]["default"],
			"joy": _default_joy(action),
		}
	return d


static func _default_joy(action: String) -> Dictionary:
	match action:
		"move_up":
			return {"type": ControlBinding.TYPE_JOY_AXIS, "axis": JOY_AXIS_LEFT_Y, "value": -1.0, "device": -1}
		"move_down":
			return {"type": ControlBinding.TYPE_JOY_AXIS, "axis": JOY_AXIS_LEFT_Y, "value": 1.0, "device": -1}
		"move_left":
			return {"type": ControlBinding.TYPE_JOY_AXIS, "axis": JOY_AXIS_LEFT_X, "value": -1.0, "device": -1}
		"move_right":
			return {"type": ControlBinding.TYPE_JOY_AXIS, "axis": JOY_AXIS_LEFT_X, "value": 1.0, "device": -1}
		"Interact":
			return {"type": ControlBinding.TYPE_JOY_BUTTON, "button": JOY_BUTTON_A, "device": -1}
		"note_up":
			return {"type": ControlBinding.TYPE_JOY_BUTTON, "button": JOY_BUTTON_DPAD_UP, "device": -1}
		"note_down":
			return {"type": ControlBinding.TYPE_JOY_BUTTON, "button": JOY_BUTTON_DPAD_DOWN, "device": -1}
		"note_left":
			return {"type": ControlBinding.TYPE_JOY_BUTTON, "button": JOY_BUTTON_DPAD_LEFT, "device": -1}
		"note_right":
			return {"type": ControlBinding.TYPE_JOY_BUTTON, "button": JOY_BUTTON_DPAD_RIGHT, "device": -1}
	return {}
