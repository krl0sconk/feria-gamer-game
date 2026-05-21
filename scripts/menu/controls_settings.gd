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


static func load_bindings() -> Dictionary:
	var bindings := _defaults()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return bindings
	for action in ACTIONS:
		bindings[action] = int(cfg.get_value("controls", action, bindings[action]))
	return bindings


static func save_bindings(bindings: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # preserva video/audio/accessibility
	for action in bindings:
		cfg.set_value("controls", action, bindings[action])
	cfg.save(SETTINGS_PATH)


static func apply_bindings(bindings: Dictionary) -> void:
	for action in bindings:
		if not InputMap.has_action(action):
			continue
		# Elimina solo InputEventKey; preserva joypad/axis
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				InputMap.action_erase_event(action, ev)
		var new_ev := InputEventKey.new()
		new_ev.physical_keycode = bindings[action]
		InputMap.action_add_event(action, new_ev)


static func key_display(physical_keycode: int) -> String:
	return OS.get_keycode_string(physical_keycode)


static func _defaults() -> Dictionary:
	var d: Dictionary = {}
	for action in ACTIONS:
		d[action] = ACTIONS[action]["default"]
	return d
