class_name ScBattle
extends Node2D

@export var chart_path: String = "res://assets/charts/test_chart.json"

# Se calcula dinámicamente desde las posiciones reales de los targets.
var _arrow_travel_ms: float = 0.0

@onready var _player_input: PlayerInput  = $PlayerInput
@onready var _music_player: MusicPlayer  = $MusicPlayer
@onready var _metronome:    Metronome    = $Metronome
@onready var _composer:     Composer     = $Composer
@onready var _judge:        Judge        = $Judge
@onready var _hud:          BattleHUD    = $BattleHUD

@onready var _left_target:  NoteTarget = $Targets/LeftTarget
@onready var _down_target:  NoteTarget = $Targets/DownTarget
@onready var _up_target:    NoteTarget = $Targets/UpTarget
@onready var _right_target: NoteTarget = $Targets/RightTarget

var _pending_notes: Dictionary = {
	"note_left": [], "note_down": [], "note_up": [], "note_right": [],
}
var _fallback_ms: float = 0.0
var _using_fallback: bool = false


func _ready() -> void:
	_connect_game_loop()
	_connect_hud()
	_load_chart()


func _connect_game_loop() -> void:
	_composer.note_expected.connect(_on_note_expected)
	_player_input.button_pressed.connect(_on_button_pressed)
	_judge.note_result.connect(_on_note_result_debug)


func _connect_hud() -> void:
	_composer.note_expected.connect(_hud._on_composer_note_expected)
	_judge.note_result.connect(_hud._on_judge_note_result)
	_hud.setup_targets(_left_target, _down_target, _up_target, _right_target)
	_arrow_travel_ms = _hud.arrow_travel_ms
	_composer.anticipation_ms = _arrow_travel_ms


func _load_chart() -> void:
	var data: ChartLoader.ChartData = ChartLoader.load_json(chart_path)
	if data.notes.is_empty():
		push_warning("ScBattle: chart vacío o no encontrado en '%s'" % chart_path)
		return
	_music_player.bpm = data.bpm
	_metronome.bpm    = data.bpm
	_composer.load_chart(data.notes)
	if _music_player.stream != null:
		_music_player.play()
	else:
		push_warning("ScBattle: sin stream de audio, corriendo en fallback.")
		_using_fallback = true


func _get_current_ms() -> float:
	return _fallback_ms if _using_fallback else _music_player.get_position_ms()


func _process(delta: float) -> void:
	if _using_fallback:
		_fallback_ms += delta * 1000.0
	var current_ms: float = _get_current_ms()
	_metronome.update_time(current_ms)
	_composer.update_time(current_ms)
	# Auto-miss
	for action in _pending_notes:
		var queue: Array = _pending_notes[action]
		while not queue.is_empty() and current_ms > queue[0].hit_ms + _metronome.window_good:
			_judge.evaluate("", queue[0].note, "Miss")
			queue.pop_front()


func _on_note_expected(note: NoteData) -> void:
	_pending_notes[note.action].append({note = note, hit_ms = note.time_ms})


func _on_button_pressed(action: String) -> void:
	var queue: Array = _pending_notes[action]
	if queue.is_empty():
		return
	var current_ms: float = _get_current_ms()
	var timing: String = _metronome.evaluate_timing(current_ms, queue[0].hit_ms)
	if timing != "Miss":
		_judge.evaluate(action, queue[0].note, timing)
		queue.pop_front()


func _on_note_result_debug(player_action: String, expected_action: String, timing: String, success: bool) -> void:
	var label: String = "HIT" if success else "MISS"
	print("[RHYTHM] %s | %s | esperada=%s | presionada=%s | t=%.0fms" % [label, timing, expected_action, player_action, _get_current_ms()])
