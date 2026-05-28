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
	var playback_s := get_playback_position()
	if OS.has_feature("web"):
		# En web la posición del stream suele ir adelantada respecto al oído y
		# respecto a las flechas animadas por delta.
		return playback_s * 1000.0
	var since_last_mix_s := AudioServer.get_time_since_last_mix()
	var corrected := playback_s + since_last_mix_s
	return corrected * 1000.0 - AudioServer.get_output_latency() * 1000.0


func log_debug_components(result_ms: float) -> void:
	RhythmClockDebug.log_music_player(
		get_playback_position(),
		AudioServer.get_time_since_last_mix(),
		AudioServer.get_output_latency(),
		result_ms
	)


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
