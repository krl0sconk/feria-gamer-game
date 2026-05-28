# Capa de datos de las opciones del juego: resolución, modo de ventana y
# volúmenes de los buses Master/SFX. Persiste en `user://settings.cfg`.
#
# SRP: este RefCounted no sabe nada de UI. Solo carga/guarda y aplica los
# valores a `DisplayServer` / `AudioServer`. La UI vive en options.gd.
#
# Patrón espejo de `ChartLoader` y `DialogueLoader`: estáticos + dato puro.
class_name OptionsSettings
extends RefCounted

const SETTINGS_PATH: String = "user://settings.cfg"

## Lista fija de resoluciones soportadas (16:9). El índice se persiste, no
## el tamaño exacto — así si en el futuro cambian estos valores, las
## preferencias siguen apuntando a "la opción que el usuario eligió".
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

const RESOLUTION_LABELS: Array[String] = [
	"1280 × 720",
	"1366 × 768",
	"1600 × 900",
	"1920 × 1080",
]

enum WindowMode { WINDOWED = 0, FULLSCREEN = 1, BORDERLESS = 2 }

const WINDOW_MODE_LABELS: Array[String] = [
	"Ventana",
	"Pantalla completa",
	"Sin bordes",
]

## Modos de daltonismo — espejo de `ColorblindOverlay.Mode`. Mantenemos los
## labels acá (capa de datos) para que la UI los consuma sin acoplarse al
## autoload.
const COLORBLIND_LABELS: Array[String] = [
	"Ninguno",
	"Protanopia",
	"Deuteranopia",
	"Tritanopia",
]

## Defaults — usados cuando no hay archivo o falta una clave.
const DEFAULT_RESOLUTION_IDX: int = 0
const DEFAULT_WINDOW_MODE: int = WindowMode.WINDOWED
const DEFAULT_MASTER_VOL: float = 80.0
const DEFAULT_SFX_VOL: float = 80.0
const DEFAULT_MUSIC_VOL: float = 80.0
const DEFAULT_COLORBLIND_MODE: int = 0
const DEFAULT_COLORBLIND_STRENGTH: float = 0.35
const DEFAULT_DYSLEXIA_MODE: bool = false

const DYSLEXIA_FONT_PATH: String = "res://assets/fonts/dyslexic_pixel.ttf"
const READABLE_FONT_PATHS: Array[String] = [
	"res://assets/fonts/retro_bound.ttf",
	"res://assets/fonts/retro_bound_uc.ttf",
]

## Mapa de nodos → ruta de fuente original. Se usa para restaurar la fuente
## cuando se desactiva el modo disléxico.
static var _original_fonts: Dictionary = {}


## Carga las preferencias del disco. Si no hay archivo o está corrupto,
## devuelve los defaults — nunca null, así la UI no necesita guards.
static func load_settings() -> Dictionary:
	var data := _defaults()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return data
	data["resolution_idx"] = int(cfg.get_value("video", "resolution_idx", data["resolution_idx"]))
	data["window_mode"] = int(cfg.get_value("video", "window_mode", data["window_mode"]))
	data["master_vol"] = float(cfg.get_value("audio", "master_vol", data["master_vol"]))
	data["sfx_vol"] = float(cfg.get_value("audio", "sfx_vol", data["sfx_vol"]))
	data["music_vol"] = float(cfg.get_value("audio", "music_vol", data["music_vol"]))
	data["colorblind_mode"] = int(cfg.get_value("accessibility", "colorblind_mode", data["colorblind_mode"]))
	data["colorblind_strength"] = float(cfg.get_value("accessibility", "colorblind_strength", data["colorblind_strength"]))
	data["dyslexia_mode"] = bool(cfg.get_value("accessibility", "dyslexia_mode", data["dyslexia_mode"]))
	return data


static func save_settings(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "resolution_idx", data.get("resolution_idx", DEFAULT_RESOLUTION_IDX))
	cfg.set_value("video", "window_mode", data.get("window_mode", DEFAULT_WINDOW_MODE))
	cfg.set_value("audio", "master_vol", data.get("master_vol", DEFAULT_MASTER_VOL))
	cfg.set_value("audio", "sfx_vol", data.get("sfx_vol", DEFAULT_SFX_VOL))
	cfg.set_value("audio", "music_vol", data.get("music_vol", DEFAULT_MUSIC_VOL))
	cfg.set_value("accessibility", "colorblind_mode", data.get("colorblind_mode", DEFAULT_COLORBLIND_MODE))
	cfg.set_value("accessibility", "colorblind_strength", data.get("colorblind_strength", DEFAULT_COLORBLIND_STRENGTH))
	cfg.set_value("accessibility", "dyslexia_mode", data.get("dyslexia_mode", DEFAULT_DYSLEXIA_MODE))
	cfg.save(SETTINGS_PATH)


## Aplica los valores al motor: tamaño de ventana, modo de display, volumen
## de los buses y modo de daltonismo. Tolera buses/autoloads inexistentes
## silenciosamente.
static func apply(data: Dictionary) -> void:
	_apply_window_mode(int(data.get("window_mode", DEFAULT_WINDOW_MODE)))
	_apply_resolution(int(data.get("resolution_idx", DEFAULT_RESOLUTION_IDX)))
	_apply_bus_volume(&"Master", float(data.get("master_vol", DEFAULT_MASTER_VOL)))
	_apply_bus_volume(&"SFX", float(data.get("sfx_vol", DEFAULT_SFX_VOL)))
	_apply_bus_volume(&"Music", float(data.get("music_vol", DEFAULT_MUSIC_VOL)))
	_apply_colorblind_mode(int(data.get("colorblind_mode", DEFAULT_COLORBLIND_MODE)))
	_apply_colorblind_strength(float(data.get("colorblind_strength", DEFAULT_COLORBLIND_STRENGTH)))
	_apply_dyslexia_mode(bool(data.get("dyslexia_mode", DEFAULT_DYSLEXIA_MODE)))


## Conveniencia: cargar del disco y aplicar de una. Llamado por Gamemanager
## en `_ready` para que las preferencias persistan entre sesiones.
static func apply_saved() -> void:
	apply(load_settings())
	ControlsSettings.apply_bindings(ControlsSettings.load_bindings())



static func _defaults() -> Dictionary:
	return {
		"resolution_idx": DEFAULT_RESOLUTION_IDX,
		"window_mode": DEFAULT_WINDOW_MODE,
		"master_vol": DEFAULT_MASTER_VOL,
		"sfx_vol": DEFAULT_SFX_VOL,
		"music_vol": DEFAULT_MUSIC_VOL,
		"colorblind_mode": DEFAULT_COLORBLIND_MODE,
		"colorblind_strength": DEFAULT_COLORBLIND_STRENGTH,
		"dyslexia_mode": DEFAULT_DYSLEXIA_MODE,
	}


static func _apply_window_mode(mode: int) -> void:
	match mode:
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		WindowMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)


static func _apply_resolution(idx: int) -> void:
	# Cambiar tamaño solo tiene efecto visible en modo Windowed; en
	# fullscreen Godot ignora el size pero lo guarda para cuando el usuario
	# vuelva a Windowed.
	if idx < 0 or idx >= RESOLUTIONS.size():
		idx = DEFAULT_RESOLUTION_IDX
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(RESOLUTIONS[idx])
		# Centramos la ventana tras el resize para que no quede a medias.
		var screen_size := DisplayServer.screen_get_size()
		var win_size := DisplayServer.window_get_size()
		DisplayServer.window_set_position((screen_size - win_size) / 2)


static func _apply_bus_volume(bus_name: StringName, linear_0_100: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	if linear_0_100 <= 0.0:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear_0_100 / 100.0))


static func _apply_colorblind_mode(mode: int) -> void:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return
	var root := (loop as SceneTree).root
	var overlay := root.get_node_or_null("ColorblindOverlay")
	if overlay != null and overlay.has_method("set_mode"):
		overlay.set_mode(mode)


static func _apply_colorblind_strength(value: float) -> void:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return
	var overlay := (loop as SceneTree).root.get_node_or_null("ColorblindOverlay")
	if overlay != null and overlay.has_method("set_strength"):
		overlay.set_strength(value)


static func _apply_dyslexia_mode(enabled: bool) -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	apply_dyslexia_fonts((loop as SceneTree).root, enabled)


static func apply_dyslexia_fonts(root: Node, enabled: bool) -> void:
	if enabled:
		if not FileAccess.file_exists(DYSLEXIA_FONT_PATH):
			push_warning("OptionsSettings: fuente disléxica no encontrada en %s" % DYSLEXIA_FONT_PATH)
			return
		var dyslexia_font: Font = load(DYSLEXIA_FONT_PATH)
		_walk_apply_font(root, dyslexia_font)
	else:
		_walk_restore_fonts(root)
		_original_fonts.clear()


static func _walk_apply_font(node: Node, dyslexia_font: Font) -> void:
	if node is Control:
		var ctrl := node as Control
		var current: Font = ctrl.get_theme_font("font")
		if current != null and current.resource_path in READABLE_FONT_PATHS:
			if not _original_fonts.has(node):
				_original_fonts[node] = current.resource_path
			ctrl.add_theme_font_override("font", dyslexia_font)
	for child in node.get_children():
		_walk_apply_font(child, dyslexia_font)


static func _walk_restore_fonts(root: Node) -> void:
	if root is Control and _original_fonts.has(root):
		var ctrl := root as Control
		var original_path: String = _original_fonts[root]
		var original_font := load(original_path) as Font
		if original_font != null:
			ctrl.add_theme_font_override("font", original_font)
		else:
			ctrl.remove_theme_font_override("font")
	for child in root.get_children():
		_walk_restore_fonts(child)
