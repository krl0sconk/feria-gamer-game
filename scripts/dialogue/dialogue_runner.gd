# Controlador de diálogos: recibe una DialogueData + un `dialogue_id`, recorre
# las líneas y emite señales al iniciar / cambiar de línea / terminar.
#
# Responsabilidad única: secuenciar. No parsea JSON ni decide qué hacer al
# terminar (eso lo resuelve el caller, típicamente un Interactable). Tampoco
# conoce la escena destino — cualquier cambio de escena se hace fuera.
class_name DialogueRunner
extends CanvasLayer

signal dialogue_started(dialogue_id: String)
signal line_started(line_index: int)
signal dialogue_finished(dialogue_id: String)

## Ruta al DialogueBox dentro del propio CanvasLayer. Por defecto "DialogueBox"
## porque el runner ES un CanvasLayer y el Box es su hijo directo — así la
## escena se puede abrir WYSIWYG en el editor (como BattleHUD).
@export var dialogue_box_path: NodePath = NodePath("DialogueBox")

@onready var _box: DialogueBox = get_node_or_null(dialogue_box_path) as DialogueBox

var _current_lines: Array[DialogueLoader.DialogueLine] = []
var _current_id: String = ""
var _index: int = -1
var _active: bool = false


func _ready() -> void:
	if _box == null:
		push_error("DialogueRunner: no se encontró DialogueBox en '%s'." % str(dialogue_box_path))
		return
	_box.advance_requested.connect(_on_advance_requested)
	_box.hide_box()


## Arranca un diálogo. `voice` es opcional — si se pasa, el DialogueBox
## reproduce ese AudioStream como blip 8-bit por cada N caracteres del
## typewriter. `null` = sin voz (silencio durante el revelado).
##
## Si el id no existe o está vacío, emite `dialogue_finished`
## inmediatamente para que el caller no quede esperando una señal que no llega.
func play(data: DialogueLoader.DialogueData, dialogue_id: String, voice: AudioStream = null) -> void:
	if _active:
		push_warning("DialogueRunner: ya hay un diálogo activo ('%s'); se ignora '%s'." % [_current_id, dialogue_id])
		return
	# Asignamos la voz antes de mostrar la primera línea, si no, el primer
	# blip podría sonar con la voz del diálogo anterior (o no sonar).
	if _box != null:
		_box.set_voice(voice)
	if data == null or not data.has_dialogue(dialogue_id):
		push_warning("DialogueRunner: diálogo '%s' no existe. Finalizando sin mostrar." % dialogue_id)
		_current_id = dialogue_id
		dialogue_started.emit(dialogue_id)
		dialogue_finished.emit(dialogue_id)
		return

	_current_lines = data.get_lines(dialogue_id)
	_current_id = dialogue_id
	_index = -1
	_active = true
	dialogue_started.emit(dialogue_id)
	_advance()


func is_playing() -> bool:
	return _active



func _on_advance_requested() -> void:
	if _active:
		_advance()


func _advance() -> void:
	_index += 1
	if _index >= _current_lines.size():
		_finish()
		return
	line_started.emit(_index)
	if _box != null:
		_box.show_line(_current_lines[_index])


func _finish() -> void:
	_active = false
	if _box != null:
		_box.hide_box()
	var id := _current_id
	_current_lines = []
	_current_id = ""
	_index = -1
	dialogue_finished.emit(id)
