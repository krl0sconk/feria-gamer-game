# Capa de pantalla completa que aplica un filtro de daltonización sobre el
# render del juego. Vive como autoload (registrado en project.godot) para
# que el filtro persista entre cambios de escena sin que ningún script de
# gameplay lo conozca.
#
# Cuando el modo es NONE el CanvasLayer se oculta — el shader pass NO se
# ejecuta, así que el costo es 0. Solo paga el shader cuando hay un modo
# activo, y aún ahí es despreciable (1 read del screen + 3 mat3*vec3).
#
# SRP: solo se ocupa del filtro visual. Persistencia y UI viven en
# OptionsSettings y la pantalla de Opciones respectivamente.
#
# Nota: NO declaramos `class_name ColorblindOverlay` porque chocaría con
# el nombre del autoload (Godot crea un símbolo global por cada uno y no
# pueden tener el mismo). Como nadie tipa contra esta clase desde otro
# script — el acceso es vía el autoload o por path — el class_name no
# aporta nada.
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
