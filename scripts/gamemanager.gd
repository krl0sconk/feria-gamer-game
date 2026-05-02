extends Node

# Singleton / autoload global. Guarda el run-state que debe sobrevivir a un
# cambio de escena (skin elegido, retorno a Map post-batalla, etc.).

var selectedskin := "idle (1)"

# ── Estado de retorno post-batalla ─────────────────────────
# Lo setea el `Interactable` justo antes de cambiar a la escena de batalla y
# lo consume el root del Map al volver (desde WinScreen o LoseScreen).

## Escena a la que se debe volver tras la batalla (típicamente Map.tscn).
var return_scene_path: String = ""

## Posición del Player al iniciar la interacción (para re-ubicarlo al volver).
var return_position: Vector2 = Vector2.ZERO

## Id del Interactable que inició la batalla. Vacío = nadie pendiente.
var pending_npc_id: String = ""

## Resultado de la batalla pendiente: "win", "lose" o "" (ninguno).
var pending_dialogue_result: String = ""


func _ready() -> void:
	# Aplicamos las preferencias guardadas (resolución, modo de ventana,
	# volúmenes) antes de que aparezca cualquier escena. Si no hay archivo
	# de settings, usa los defaults.
	OptionsSettings.apply_saved()


func _process(_delta: float) -> void:
	pass


## Limpia los campos de retorno. Llamado por el root del Map después de
## reanudar el diálogo de resultado.
func clear_pending_dialogue() -> void:
	return_scene_path = ""
	return_position = Vector2.ZERO
	pending_npc_id = ""
	pending_dialogue_result = ""
