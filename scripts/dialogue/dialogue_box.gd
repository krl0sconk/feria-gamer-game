# Vista del diálogo. Renderiza una `DialogueLine` con efecto typewriter
# (revelado letra por letra) y reproduce un "blip" estilo 8-bit cada N
# caracteres como voz del personaje.
#
# Comportamiento de input (`ui_accept`):
#   1ra pulsación → completa la línea al instante (skip del typewriter).
#   2da pulsación → emite `advance_requested` (avanzar al siguiente).
#
# La voz se setea por línea desde afuera (`set_voice()`) — el box no sabe
# de NPCs ni de quién habla, solo reproduce lo que le indiquen.
class_name DialogueBox
extends Control

## Se emite cuando el jugador presiona `ui_accept` y la línea ya estaba
## completamente revelada (queremos pasar a la siguiente).
signal advance_requested

@export var speaker_label_path: NodePath = NodePath("Panel/Margin/VBox/SpeakerLabel")
@export var text_label_path: NodePath = NodePath("Panel/Margin/VBox/TextLabel")
@export var hint_label_path: NodePath = NodePath("Panel/Margin/VBox/HintLabel")

@export_group("Typewriter")
## Velocidad de revelado en caracteres por segundo.
@export var chars_per_second: float = 30.0
## Cada cuántos caracteres "audibles" (sin contar espacios/puntuación) suena
## el blip. 1 = cada letra; 2 = cada dos; subir si tu voice es muy chillón.
@export var sound_every_n_chars: int = 2
## Variación aleatoria del pitch (±). 0 = monótono. 0.1 = ±10%.
@export var pitch_jitter: float = 0.08
## Volumen base del blip en dB.
@export var voice_volume_db: float = -4.0
## Bus de audio. Cae a "Master" si no existe.
@export var voice_bus: StringName = &"SFX"

@onready var _speaker_label: Label = get_node_or_null(speaker_label_path) as Label
@onready var _text_label: Label = get_node_or_null(text_label_path) as Label
@onready var _hint_label: Label = get_node_or_null(hint_label_path) as Label

# Caracteres que NO disparan blip (se revelan pero no suenan). Mantiene
# natural la cadencia frente a espacios y puntuación.
const _SILENT_CHARS: String = " \n\t.,;:!?¡¿—-…\"'()"

var _voice_player: AudioStreamPlayer = null
var _voice_stream: AudioStream = null
var _current_text: String = ""
var _chars_revealed: int = 0
var _chars_since_last_blip: int = 0
var _accumulator: float = 0.0
var _typing_complete: bool = true


func _ready() -> void:
	hide_box()
	set_process_unhandled_input(true)
	_setup_voice_player()


func _setup_voice_player() -> void:
	_voice_player = AudioStreamPlayer.new()
	_voice_player.volume_db = voice_volume_db
	if AudioServer.get_bus_index(voice_bus) != -1:
		_voice_player.bus = voice_bus
	else:
		_voice_player.bus = &"Master"
	add_child(_voice_player)


## Asigna la voz que se usará en los siguientes `show_line()`. Pasar `null`
## desactiva el blip (silencio total durante el typewriter — útil para
## diálogos de objetos sin speaker).
func set_voice(stream: AudioStream) -> void:
	_voice_stream = stream
	if _voice_player != null:
		_voice_player.stream = stream


func show_line(line: DialogueLoader.DialogueLine) -> void:
	visible = true
	if _speaker_label != null:
		if line.speaker.is_empty():
			_speaker_label.visible = false
			_speaker_label.text = ""
		else:
			_speaker_label.visible = true
			_speaker_label.text = line.speaker
	if _text_label != null:
		_current_text = line.text
		_text_label.text = _current_text
		_text_label.visible_characters = 0
	_chars_revealed = 0
	_chars_since_last_blip = 0
	_accumulator = 0.0
	_typing_complete = _current_text.is_empty()


func hide_box() -> void:
	visible = false
	_typing_complete = true


## True si el texto se sigue revelando (típewriter en curso).
func is_typing() -> bool:
	return not _typing_complete


## Salta el typewriter: muestra todo el texto de una. Usado al primer
## `ui_accept` mientras se escribe.
func complete_line() -> void:
	if _text_label != null:
		_text_label.visible_characters = -1
	_chars_revealed = _current_text.length()
	_typing_complete = true



func _process(delta: float) -> void:
	if _typing_complete or not visible or _text_label == null:
		return
	_accumulator += delta * chars_per_second
	while _accumulator >= 1.0 and _chars_revealed < _current_text.length():
		_accumulator -= 1.0
		_chars_revealed += 1
		_text_label.visible_characters = _chars_revealed
		var ch: String = _current_text.substr(_chars_revealed - 1, 1)
		if not _SILENT_CHARS.contains(ch):
			_chars_since_last_blip += 1
			if _chars_since_last_blip >= sound_every_n_chars:
				_chars_since_last_blip = 0
				_play_blip()
	if _chars_revealed >= _current_text.length():
		_typing_complete = true


func _play_blip() -> void:
	if _voice_player == null or _voice_stream == null:
		return
	# Jitter de pitch para que no suene robótico — cada blip es un poco
	# distinto al anterior. Truco standard de juegos 8/16-bit.
	if pitch_jitter > 0.0:
		_voice_player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	else:
		_voice_player.pitch_scale = 1.0
	_voice_player.play()



func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		# Convención clásica de RPG/AVG:
		#   - Si está escribiendo → primer accept completa la línea.
		#   - Si ya está completa → segundo accept avanza.
		if not _typing_complete:
			complete_line()
		else:
			advance_requested.emit()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
