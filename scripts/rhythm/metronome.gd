# Rastrea el beat actual y evalúa la precisión del jugador.
# Solo MusicPlayer debe llamar update_time() directamente.
class_name Metronome
extends Node

signal beat_hit(beat_number: int)

@export var bpm: float = 120.0
# Ventanas de tiempo en ms para cada calificación
@export var window_perfect: float = 50.0
@export var window_good: float = 120.0

var _current_beat: int = -1


func update_time(ms: float) -> void:
	var beat_duration_ms: float = (60.0 / bpm) * 1000.0
	var new_beat: int = int(ms / beat_duration_ms)
	if new_beat != _current_beat:
		_current_beat = new_beat
		beat_hit.emit(_current_beat)


# Retorna "Perfect", "Good" o "Miss" según la diferencia en ms entre pulsación y beat.
func evaluate_timing(press_time_ms: float, beat_time_ms: float) -> String:
	var diff: float = abs(press_time_ms - beat_time_ms)
	if diff <= window_perfect:
		return "Perfect"
	elif diff <= window_good:
		return "Good"
	return "Miss"
