# Pantalla de derrota post-batalla.
#
# Flujo:
#   - Battle detecta derrota -> setea `Gamemanager.pending_dialogue_result = "lose"`
#     y cambia a `LoseScreen.tscn`.
#   - Esta pantalla reproduce el SFX de derrota.
#   - Cuando termina el SFX, vuelve automáticamente al `return_scene_path`
#     guardado por el `Interactable` original.
#   - El Map reanuda el diálogo de derrota al reentrar.
#
# Responsabilidad única: mostrar la derrota, reproducir su audio y volver al mapa.
class_name LoseScreen
extends Control

@export_file("*.tscn") var fallback_scene_path: String = "res://scenes/map/map.tscn"
@export var auto_return_delay_seconds: float = 2.0
@export var sfx_player_path: NodePath = NodePath("SfxPlayer")

var _returning: bool = false


func _ready() -> void:
	var sfx := get_node_or_null(sfx_player_path) as AudioStreamPlayer
	if sfx != null and sfx.stream != null:
		if not sfx.finished.is_connected(_go_back):
			sfx.finished.connect(_go_back)
		sfx.play()
		var delay_seconds: float = auto_return_delay_seconds
		var length_seconds: float = sfx.stream.get_length()
		if length_seconds > 0.0:
			delay_seconds = max(length_seconds + 0.05, auto_return_delay_seconds)
		_queue_return(delay_seconds)
		return
	_queue_return(auto_return_delay_seconds)


func _queue_return(delay_seconds: float) -> void:
	if delay_seconds < 0.0:
		delay_seconds = 0.0
	var timer := get_tree().create_timer(delay_seconds)
	timer.timeout.connect(_go_back)


func _go_back() -> void:
	if _returning:
		return
	_returning = true
	var target: String = Gamemanager.return_scene_path
	if target.is_empty():
		target = fallback_scene_path
	get_tree().change_scene_to_file(target)