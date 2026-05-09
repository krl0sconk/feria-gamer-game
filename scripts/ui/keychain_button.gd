# Botón estilo "llavero": al recibir hover (mouse) o focus (teclado/joystick),
# oscila como un péndulo amortiguado y reproduce un SFX opcional.
#
# Diseñado para reemplazar el script de cualquier `Button` sin cambiar
# jerarquía, signals `pressed` ni estilos. La animación pivota en el
# top-center del rect (donde está la "anilla" del llavero).
#
# SRP: este nodo solo se ocupa de animación + sonido en hover/focus.
# No conoce navegación, layout ni el contenido del menú.
class_name KeychainButton
extends Button

@export_group("Swing")
## Secuencia de ángulos del pendulum decay (oscilación inicial al recibir
## hover/focus). Se interpola con SINE+EASE_OUT. El último ángulo NO es
## el resting — para eso usá `rest_angle_deg`.
@export var swing_angles_deg: Array[float] = [-8.0, 6.0, -4.0, 2.0]
## Ángulo en el que queda el botón mientras sigue activo (highlighted),
## tras agotarse el swing. Default -3° = ligeramente torcido para que se
## vea cuál está seleccionado. Poné 0.0 si querés que vuelva totalmente
## recto.
@export var rest_angle_deg: float = -3.0
## Duración de cada paso del swing (segundos). Total swing = pasos * step.
@export var swing_step_seconds: float = 0.09
## Tiempo de recovery a 0° cuando se pierden todos los highlights.
@export var recover_seconds: float = 0.18
## Si true, pivota en (size.x/2, 0) — la anilla queda fija arriba. Si false,
## pivota en el centro del rect.
@export var pivot_top_center: bool = true

@export_group("Sonido")
## SFX que suena al ganar highlight (mouse_entered o focus_entered). Si es
## null, el botón funciona en silencio sin warnings en consola.
@export var hover_sfx: AudioStream = null
## Volumen del SFX en dB. -6 dB ≈ mitad de volumen percibido.
@export var hover_volume_db: float = -6.0
## Bus de audio para enrutar el SFX. Si no existe, cae a "Master".
@export var hover_bus: StringName = &"SFX"



var _active_tween: Tween = null
var _sfx_player: AudioStreamPlayer = null
# Tracking de fuentes de "highlight" — un swing nuevo se dispara solo en la
# transición 0→1 fuentes activas; recovery solo en 1→0. Evita doble-trigger
# si el mouse pasa sobre un botón que ya tiene focus de joystick.
var _highlight_sources: Dictionary = {"mouse": false, "focus": false}


func _ready() -> void:
	# FOCUS_ALL asegura que el sistema nativo de Godot mueva el foco con
	# ui_up/ui_down (teclado y D-Pad/stick del gamepad).
	focus_mode = Control.FOCUS_ALL
	# Quitamos el rectángulo de focus por defecto: el swing del llavero ya
	# comunica visualmente cuál botón está activo. Si en el futuro quisieras
	# devolverlo (ej. para accesibilidad), remové este override.
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_setup_pivot()
	resized.connect(_setup_pivot)
	mouse_entered.connect(_on_highlight_gained.bind("mouse"))
	mouse_exited.connect(_on_highlight_lost.bind("mouse"))
	focus_entered.connect(_on_highlight_gained.bind("focus"))
	focus_exited.connect(_on_highlight_lost.bind("focus"))
	_setup_sfx()


func _setup_pivot() -> void:
	if pivot_top_center:
		pivot_offset = Vector2(size.x * 0.5, 0.0)
	else:
		pivot_offset = size * 0.5


func _setup_sfx() -> void:
	if hover_sfx == null:
		return
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.stream = hover_sfx
	_sfx_player.volume_db = hover_volume_db
	# Fallback a Master si el bus configurado no existe.
	if AudioServer.get_bus_index(hover_bus) != -1:
		_sfx_player.bus = hover_bus
	else:
		_sfx_player.bus = &"Master"
	add_child(_sfx_player)



func _on_highlight_gained(source: String) -> void:
	var was_highlighted := _is_any_highlighted()
	_highlight_sources[source] = true
	if not was_highlighted:
		_start_swing()
		_play_sfx()


func _on_highlight_lost(source: String) -> void:
	_highlight_sources[source] = false
	if not _is_any_highlighted():
		_start_recover()


func _is_any_highlighted() -> bool:
	for active in _highlight_sources.values():
		if active:
			return true
	return false



func _start_swing() -> void:
	_kill_active_tween()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for angle_deg in swing_angles_deg:
		tw.tween_property(self, "rotation_degrees", angle_deg, swing_step_seconds)
	# Cierre: el último paso lleva al `rest_angle_deg` (ligeramente torcido
	# por defecto), que es el "está seleccionado" en estado quieto.
	tw.tween_property(self, "rotation_degrees", rest_angle_deg, swing_step_seconds)
	_active_tween = tw


func _start_recover() -> void:
	_kill_active_tween()
	var tw := create_tween()
	tw.tween_property(self, "rotation_degrees", 0.0, recover_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween = tw


func _kill_active_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null



func _play_sfx() -> void:
	if _sfx_player == null:
		return
	# `play()` reinicia desde el inicio aunque ya estuviese sonando — es
	# justo lo que querés con un jingle corto en hover repetido.
	_sfx_player.play()
