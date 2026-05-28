# Pantalla de opciones — pensada como overlay sobre el main menu (puede
# correrse standalone con F6 para debug). Consume `OptionsSettings` para
# leer/escribir y aplicar las preferencias, y `ControlsSettings` para
# el remapeo de teclas y mando.
#
# Flujo Apply explícito: los cambios en sliders/dropdowns/teclas NO tocan el
# motor hasta que se aprieta "Aplicar". "Volver" cierra el overlay; si
# nunca se apretó Aplicar, los cambios pendientes se descartan.
extends Control

## Emitida al cerrar el overlay con "Volver".
signal closed

enum ListenMode { NONE, KEYBOARD, JOY }

@onready var _resolution_option: OptionButton = %ResolutionOption
@onready var _window_option: OptionButton = %WindowOption
@onready var _master_slider: HSlider = %MasterSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _music_slider: HSlider = %MusicSlider
@onready var _master_value_label: Label = %MasterValue
@onready var _sfx_value_label: Label = %SfxValue
@onready var _music_value_label: Label = %MusicValue
@onready var _colorblind_option: OptionButton = %ColorblindOption
@onready var _intensity_slider: HSlider = %IntensitySlider
@onready var _intensity_label: Label = %IntensityValue
@onready var _dyslexia_check: CheckButton = %DyslexiaCheck
@onready var _apply_button: Button = %ApplyButton
@onready var _back_button: Button = %BackButton

var _settings: Dictionary = {}

# action_name -> {"key": int, "joy": Dictionary}
var _pending_bindings: Dictionary = {}
var _listening_row: RebindRow = null
var _listen_mode: ListenMode = ListenMode.NONE


func _ready() -> void:
	_settings = OptionsSettings.load_settings()
	_pending_bindings = ControlsSettings.load_bindings()
	_populate_dropdowns()
	_apply_to_ui()
	_connect_signals()
	_populate_rebind_rows()
	_apply_button.grab_focus()


func _input(event: InputEvent) -> void:
	if _listening_row == null or _listen_mode == ListenMode.NONE:
		return

	if _listen_mode == ListenMode.KEYBOARD:
		if not (event is InputEventKey) or not event.pressed or event.echo:
			return
		var key := event as InputEventKey
		if key.physical_keycode == KEY_ESCAPE:
			_stop_listening()
			accept_event()
			return
		_pending_bindings[_listening_row.action_name]["key"] = key.physical_keycode
		_listening_row.set_keycode(key.physical_keycode)
		_stop_listening()
		accept_event()
		return

	if _listen_mode == ListenMode.JOY:
		var binding := ControlBinding.from_input_event(event)
		if binding.is_empty():
			return
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			_stop_listening()
			accept_event()
			return
		_pending_bindings[_listening_row.action_name]["joy"] = binding
		_listening_row.set_joy_binding(binding)
		_stop_listening()
		accept_event()


func _populate_dropdowns() -> void:
	_resolution_option.clear()
	for label in OptionsSettings.RESOLUTION_LABELS:
		_resolution_option.add_item(label)
	_window_option.clear()
	for label in OptionsSettings.WINDOW_MODE_LABELS:
		_window_option.add_item(label)
	_colorblind_option.clear()
	for label in OptionsSettings.COLORBLIND_LABELS:
		_colorblind_option.add_item(label)
	var dropdown_font: Font = _resolution_option.get_theme_font("font")
	var dropdown_font_size: int = _resolution_option.get_theme_font_size("font_size")
	for option in [_resolution_option, _window_option, _colorblind_option]:
		var popup: PopupMenu = option.get_popup()
		popup.add_theme_font_override("font", dropdown_font)
		popup.add_theme_font_size_override("font_size", dropdown_font_size)


func _apply_to_ui() -> void:
	_resolution_option.selected = int(_settings["resolution_idx"])
	_window_option.selected = int(_settings["window_mode"])
	_master_slider.value = float(_settings["master_vol"])
	_sfx_slider.value = float(_settings["sfx_vol"])
	_music_slider.value = float(_settings["music_vol"])
	_colorblind_option.selected = int(_settings["colorblind_mode"])
	_intensity_slider.value = float(_settings["colorblind_strength"])
	_intensity_label.text = "%d%%" % int(_settings["colorblind_strength"] * 100.0)
	_dyslexia_check.button_pressed = bool(_settings["dyslexia_mode"])
	_update_volume_labels()


func _connect_signals() -> void:
	_resolution_option.item_selected.connect(_on_resolution_selected)
	_window_option.item_selected.connect(_on_window_mode_selected)
	_master_slider.value_changed.connect(_on_master_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_colorblind_option.item_selected.connect(_on_colorblind_selected)
	_intensity_slider.value_changed.connect(_on_intensity_changed)
	_dyslexia_check.toggled.connect(_on_dyslexia_toggled)
	_apply_button.pressed.connect(_on_apply_pressed)
	_back_button.pressed.connect(_on_back_pressed)


func _populate_rebind_rows() -> void:
	var rows := find_children("*", "RebindRow", true, false)
	for row_node in rows:
		var row := row_node as RebindRow
		var action := row.action_name
		if action.is_empty() or not ControlsSettings.ACTIONS.has(action):
			continue
		var lbl := row.get_node_or_null("ActionLabel") as Label
		if lbl:
			lbl.text = ControlsSettings.ACTIONS[action]["label"]
		var entry: Dictionary = _pending_bindings.get(action, ControlsSettings.default_bindings()[action])
		row.set_keycode(int(entry.get("key", ControlsSettings.ACTIONS[action]["default"])))
		row.set_joy_binding(entry.get("joy", ControlsSettings.default_joy_for(action)))
		row.rebind_requested.connect(_on_rebind_requested)
		row.joy_rebind_requested.connect(_on_joy_rebind_requested)
		row.reset_requested.connect(_on_reset_requested)


func _on_rebind_requested(row: RebindRow) -> void:
	_start_listening(row, ListenMode.KEYBOARD)


func _on_joy_rebind_requested(row: RebindRow) -> void:
	_start_listening(row, ListenMode.JOY)


func _start_listening(row: RebindRow, mode: ListenMode) -> void:
	if _listening_row != null and _listening_row != row:
		_stop_listening()
	_listening_row = row
	_listen_mode = mode
	if mode == ListenMode.KEYBOARD:
		row.set_listening_keyboard(true)
	else:
		row.set_listening_joy(true)


func _stop_listening() -> void:
	if _listening_row == null:
		_listen_mode = ListenMode.NONE
		return
	_listening_row.set_listening_keyboard(false)
	_listening_row.set_listening_joy(false)
	_listening_row = null
	_listen_mode = ListenMode.NONE


func _on_reset_requested(row: RebindRow) -> void:
	_stop_listening()
	var defaults: Dictionary = ControlsSettings.default_bindings()[row.action_name]
	_pending_bindings[row.action_name] = defaults.duplicate(true)
	row.set_keycode(int(defaults["key"]))
	row.set_joy_binding(defaults.get("joy", {}))


func _on_resolution_selected(idx: int) -> void:
	_settings["resolution_idx"] = idx


func _on_window_mode_selected(idx: int) -> void:
	_settings["window_mode"] = idx


func _on_master_changed(value: float) -> void:
	_settings["master_vol"] = value
	_update_volume_labels()


func _on_sfx_changed(value: float) -> void:
	_settings["sfx_vol"] = value
	_update_volume_labels()


func _on_music_changed(value: float) -> void:
	_settings["music_vol"] = value
	_update_volume_labels()


func _on_colorblind_selected(idx: int) -> void:
	_settings["colorblind_mode"] = idx


func _on_intensity_changed(value: float) -> void:
	_settings["colorblind_strength"] = value
	_intensity_label.text = "%d%%" % int(value * 100.0)


func _on_dyslexia_toggled(pressed: bool) -> void:
	_settings["dyslexia_mode"] = pressed


func _on_apply_pressed() -> void:
	OptionsSettings.save_settings(_settings)
	OptionsSettings.apply(_settings)
	ControlsSettings.save_bindings(_pending_bindings)
	ControlsSettings.apply_bindings(_pending_bindings)


func _on_back_pressed() -> void:
	closed.emit()
	queue_free()


func _update_volume_labels() -> void:
	_master_value_label.text = "%d%%" % int(_master_slider.value)
	_sfx_value_label.text = "%d%%" % int(_sfx_slider.value)
	_music_value_label.text = "%d%%" % int(_music_slider.value)
