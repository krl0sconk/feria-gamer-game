# Capa de pantalla completa que aplica un filtro de daltonización sobre el
# render del juego.
extends CanvasLayer

enum Mode { NONE = 0, PROTANOPIA = 1, DEUTERANOPIA = 2, TRITANOPIA = 3 }

const MODE_LABELS: Array[String] = [
	"Ninguno",
	"Protanopia",
	"Deuteranopia",
	"Tritanopia",
]

@onready var _rect: ColorRect = $FullscreenRect


func _ready() -> void:
	# Default oculto — recién se enciende cuando OptionsSettings.apply()
	# nos llama tras leer las preferencias guardadas.
	visible = false


## Cambia el modo de filtro. Llamado desde `OptionsSettings.apply()`.
func set_mode(mode: int) -> void:
	if mode <= Mode.NONE or mode > Mode.TRITANOPIA:
		visible = false
		return
	visible = true
	if _rect != null and _rect.material is ShaderMaterial:
		(_rect.material as ShaderMaterial).set_shader_parameter("mode", mode)
