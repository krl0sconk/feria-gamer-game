# Pantalla de opciones — pensada como overlay sobre el main menu (puede
# correrse standalone con F6 para debug). Consume `OptionsSettings` para
# leer/escribir y aplicar las preferencias.
#
# Flujo Apply explícito: los cambios en sliders/dropdowns NO tocan el
# motor hasta que se aprieta "Aplicar". "Volver" cierra el overlay; si
# nunca se apretó Aplicar, los cambios pendientes se descartan (porque
# nunca se llegaron a guardar/aplicar).
extends Control

## Emitida al cerrar el overlay con "Volver". El padre (main_menu) lo
## escucha para liberar la instancia y restaurar el focus.
signal closed

@onready var _resolution_option: OptionButton = %ResolutionOption
@onready var _window_option: OptionButton = %WindowOption
@onready var _master_slider: HSlider = %MasterSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _master_value_label: Label = %MasterValue
@onready var _sfx_value_label: Label = %SfxValue
@onready var _colorblind_option: OptionButton = %ColorblindOption
@onready var _apply_button: Button = %ApplyButton
@onready var _back_button: Button = %BackButton

# Estado pendiente: refleja la UI. Se persiste/aplica al apretar Aplicar.
# Inicialmente espeja lo guardado en disco.
var _settings: Dictionary = {}


func _ready() -> void:
	_settings = OptionsSettings.load_settings()
	_populate_dropdowns()
	_apply_to_ui()
	_connect_signals()
	_apply_button.grab_focus()


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


func _apply_to_ui() -> void:
	_resolution_option.selected = int(_settings["resolution_idx"])
	_window_option.selected = int(_settings["window_mode"])
	_master_slider.value = float(_settings["master_vol"])
	_sfx_slider.value = float(_settings["sfx_vol"])
	_colorblind_option.selected = int(_settings["colorblind_mode"])
	_update_volume_labels()


func _connect_signals() -> void:
	# Cada handler solo actualiza el dict pendiente y los labels — sin
	# tocar disco ni motor. La aplicación real es responsabilidad del
	# botón Aplicar.
	_resolution_option.item_selected.connect(_on_resolution_selected)
	_window_option.item_selected.connect(_on_window_mode_selected)
	_master_slider.value_changed.connect(_on_master_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_colorblind_option.item_selected.connect(_on_colorblind_selected)
	_apply_button.pressed.connect(_on_apply_pressed)
	_back_button.pressed.connect(_on_back_pressed)



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


func _on_colorblind_selected(idx: int) -> void:
	_settings["colorblind_mode"] = idx


func _on_apply_pressed() -> void:
	OptionsSettings.save_settings(_settings)
	OptionsSettings.apply(_settings)


func _on_back_pressed() -> void:
	closed.emit()
	queue_free()



func _update_volume_labels() -> void:
	_master_value_label.text = "%d%%" % int(_master_slider.value)
	_sfx_value_label.text = "%d%%" % int(_sfx_slider.value)
