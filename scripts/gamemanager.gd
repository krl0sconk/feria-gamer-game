extends Node

# Singleton / autoload global. Guarda el run-state que debe sobrevivir a un
# cambio de escena (skin elegido, retorno a Map post-batalla, etc.).

var selectedskin := "idle (1)"

## Posición guardada que se debe re-aplicar cuando cargamos una partida.
var loaded_position: Vector2 = Vector2.ZERO

## Indica si `loaded_position` tiene un valor pendiente por consumir.
var has_loaded_position: bool = false

## Escena a la que se debe volver tras la batalla (típicamente Map.tscn).
var return_scene_path: String = ""

## Posición del Player al iniciar la interacción (para re-ubicarlo al volver).
var return_position: Vector2 = Vector2.ZERO

## Id del Interactable que inició la batalla. Vacío = nadie pendiente.
var pending_npc_id: String = ""

## Resultado de la batalla pendiente: "win", "lose" o "" (ninguno).
var pending_dialogue_result: String = ""


func _ready() -> void:
	OptionsSettings.apply_saved()
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node.get_parent() != get_tree().root:
		return
	var settings := OptionsSettings.load_settings()
	if bool(settings.get("dyslexia_mode", false)):
		OptionsSettings.apply_dyslexia_fonts(node, true)


## Limpia los campos de retorno. Llamado por el root del Map después de
## reanudar el diálogo de resultado.
func clear_pending_dialogue() -> void:
	return_scene_path = ""
	return_position = Vector2.ZERO
	pending_npc_id = ""
	pending_dialogue_result = ""


func set_loaded_position(position: Vector2) -> void:
	loaded_position = position
	has_loaded_position = true


func consume_loaded_position() -> Vector2:
	has_loaded_position = false
	return loaded_position
