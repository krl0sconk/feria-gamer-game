extends Control

const OPTIONS_SCENE: PackedScene = preload("res://scenes/menu/options.tscn")

@onready var _start_button: Button = $Start
@onready var _options_button: Button = $Options
@onready var _exit_button: Button = $Exit

# Instancia activa del overlay de opciones (null si está cerrado).
var _options_overlay: Control = null


func _ready() -> void:
	# Damos focus inicial al botón Play para que el joystick / teclado puedan
	# navegar desde el primer frame. El KeychainButton dispara su swing al
	# recibir focus_entered, así sirve como hint visual de "este es el activo".
	_start_button.grab_focus()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_options_pressed() -> void:
	# Guard anti-doble-instanciación: si el overlay ya está abierto, no hacer
	# nada (un click rápido podría re-disparar `pressed` antes de cerrarse).
	if _options_overlay != null:
		return
	_options_overlay = OPTIONS_SCENE.instantiate()
	_options_overlay.closed.connect(_on_options_closed)
	add_child(_options_overlay)
	# Bloqueamos el focus de los botones del menú mientras el overlay está
	# arriba, así el joystick no salta del panel al menú detrás.
	_set_menu_buttons_focusable(false)


func _on_options_closed() -> void:
	_options_overlay = null
	_set_menu_buttons_focusable(true)
	# El usuario "vuelve" al botón que abrió el panel — focus en Options
	# dispara su swing como confirmación visual.
	_options_button.grab_focus()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/select_pj.tscn")


func _on_back_pressed() -> void:
	pass


# ── Helpers ────────────────────────────────────────────────

func _set_menu_buttons_focusable(active: bool) -> void:
	var mode := Control.FOCUS_ALL if active else Control.FOCUS_NONE
	_start_button.focus_mode = mode
	_options_button.focus_mode = mode
	_exit_button.focus_mode = mode
