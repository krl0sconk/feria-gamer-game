# Controla la reproducción del audio y expone el tiempo actual en ms.
class_name MusicPlayer
extends AudioStreamPlayer

signal music_started()
signal time_updated(ms: float)

@export var bpm: float = 120.0

# Detectar el primer frame en que playing pasa a true
var _was_playing: bool = false


func _process(_delta: float) -> void:
	if playing and not _was_playing:
		music_started.emit()
	_was_playing = playing

	if playing:
		time_updated.emit(get_position_ms())


func get_position_ms() -> float:
	return get_playback_position() * 1000.0


func switch_stream(new_stream: AudioStream, offset_sec: float) -> void:
	stream = new_stream
	play(maxf(offset_sec, 0.0))


func fade_in(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "volume_db", 0.0, duration)
	await tween.finished


func fade_out(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "volume_db", -80.0, duration)
	await tween.finished
