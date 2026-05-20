class_name Battle
extends Node2D

@export var chart_path: String = "res://assets/charts/test_chart.json"

@export_file("*.tscn") var lose_scene_path: String = ""
@export_file("*.tscn") var win_scene_path: String = "res://scenes/rhythm/win_screen.tscn"
@export_file("*.tscn") var fallback_map_scene_path: String = "res://scenes/map/map.tscn"

@export_group("Delays")
## Pausa extra antes de que arranque la música (encima del pre-roll técnico).
@export_range(0.0, 5.0, 0.1, "suffix:s") var intro_delay_s: float = 0.0
## Pausa tras terminar el nivel antes de cambiar a la pantalla de resultado.
@export_range(0.0, 5.0, 0.1, "suffix:s") var outro_delay_s: float = 1.5

var _arrow_travel_ms: float = 0.0

@onready var _player_input: PlayerInput = $PlayerInput
@onready var _music_player: MusicPlayer = $MusicPlayer
@onready var _metronome: Metronome = $Metronome
@onready var _composer: Composer = $Composer
@onready var _judge: Judge = $Judge
@onready var _referee: Referee = $Referee
@onready var _enemy_gauge: EnemyGauge = $EnemyGauge
@onready var _hud: BattleHUD = $BattleHUD
@onready var _enemy_battle: Node2D = $EnemyBattle
@onready var _transition_runner: DialogueRunner = $TransitionRunner

@onready var _left_target: NoteTarget = $Targets/LeftTarget
@onready var _down_target: NoteTarget = $Targets/DownTarget
@onready var _up_target: NoteTarget = $Targets/UpTarget
@onready var _right_target: NoteTarget = $Targets/RightTarget

var _pending_notes: Dictionary = {
	"note_left": [], "note_down": [], "note_up": [], "note_right": [],
}
var _fallback_ms: float = 0.0
var _using_fallback: bool = false
var _last_note_ms: float = 0.0
var _survival_declared: bool = false
var _level_ended: bool = false
var _chart_data: ChartLoader.ChartData
var _current_phase_idx: int = 0
var _phase_audio_offset_ms: float = 0.0
var _phase_transition_active: bool = false

# Pre-roll: tiempo negativo antes de que arranque la música para que las
# notas iniciales tengan margen de viaje hasta el target.
var _in_pre_roll: bool = false
var _pre_roll_elapsed_ms: float = 0.0
var _pre_roll_total_ms: float = 0.0


func _ready() -> void:
	var override_chart_path: String = Gamemanager.consume_pending_battle_chart_path()
	if override_chart_path != "":
		chart_path = override_chart_path
	var override_music: AudioStream = Gamemanager.consume_pending_battle_music()
	if override_music != null:
		_music_player.stream = override_music
	_connect_game_loop()
	_connect_hud()
	_load_chart()


func _connect_game_loop() -> void:
	_composer.note_expected.connect(_on_note_expected)
	_player_input.button_pressed.connect(_on_button_pressed)
	_judge.note_result.connect(_on_note_result_debug)
	_judge.note_result.connect(_referee.on_note_result)
	_referee.level_ended.connect(_on_level_ended)


func _connect_hud() -> void:
	_composer.note_expected.connect(_hud._on_composer_note_expected)
	_judge.note_result.connect(_hud._on_judge_note_result)
	_player_input.button_pressed.connect(_hud.on_player_pressed)
	_referee.player_hp_updated.connect(_hud.on_player_hp_updated)
	_referee.score_updated.connect(_hud.on_score_updated)
	_referee.combo_updated.connect(_hud.on_combo_updated)
	_enemy_gauge.enemy_hp_updated.connect(_hud.on_enemy_hp_updated)
	_hud.setup_targets(_left_target, _down_target, _up_target, _right_target)
	_arrow_travel_ms = _hud.arrow_travel_ms
	_composer.anticipation_ms = _arrow_travel_ms


func _load_chart() -> void:
	_chart_data = ChartLoader.load_json(chart_path)
	if _chart_data.notes.is_empty():
		push_warning("Battle: chart vacío o no encontrado en '%s'" % chart_path)
		return
	if _chart_data.phases.is_empty():
		push_warning("Battle: chart sin phases, usando BPM por defecto.")
		var p := ChartLoader.PhaseData.new()
		_chart_data.phases.append(p)
	var phase0: ChartLoader.PhaseData = _chart_data.phases[0]
	_music_player.bpm = phase0.bpm
	_metronome.bpm = phase0.bpm
	_composer.load_chart(_chart_data.notes)
	_last_note_ms = _chart_data.notes[_chart_data.notes.size() - 1].time_ms
	_current_phase_idx = 0
	_phase_audio_offset_ms = 0.0
	_pre_roll_total_ms = _arrow_travel_ms + intro_delay_s * 1000.0
	_pre_roll_elapsed_ms = 0.0
	_in_pre_roll = true


func _get_current_ms() -> float:
	if _in_pre_roll:
		return _pre_roll_elapsed_ms - _pre_roll_total_ms + _phase_audio_offset_ms
	return _fallback_ms if _using_fallback else _music_player.get_position_ms() + _phase_audio_offset_ms


func _get_song_total_ms() -> float:
	if not _using_fallback and _music_player.stream != null:
		var length_s: float = _music_player.stream.get_length()
		if length_s > 0.0:
			return length_s * 1000.0
	return _last_note_ms


func _process(delta: float) -> void:
	if _level_ended:
		return
	if _phase_transition_active:
		return
	if _in_pre_roll:
		_pre_roll_elapsed_ms += delta * 1000.0
		if _pre_roll_elapsed_ms >= _pre_roll_total_ms:
			_in_pre_roll = false
			if _music_player.stream != null:
				_music_player.volume_db = -80.0
				_music_player.play()
				_music_player.fade_in(1.0)
			else:
				_using_fallback = true
	elif _using_fallback:
		_fallback_ms += delta * 1000.0
	var current_ms: float = _get_current_ms()
	_metronome.update_time(current_ms)
	_composer.update_time(current_ms)
	_check_phase_transition(current_ms)

	# Progreso escénico del enemigo.
	var total_ms: float = _get_song_total_ms()
	if total_ms > 0.0:
		_enemy_gauge.update_song_progress(maxf(current_ms, 0.0) / total_ms)

	for action in _pending_notes:
		if _level_ended:
			break
		var queue: Array = _pending_notes[action]
		while not queue.is_empty() and current_ms > queue[0].hit_ms + _metronome.window_good:
			if not queue[0].note.is_fake:
				_judge.evaluate("", queue[0].note, "Miss")
			queue.pop_front()
			if _level_ended:
				break

	if not _survival_declared and current_ms >= _last_note_ms + _metronome.window_good and _all_queues_empty():
		_survival_declared = true
		_referee.declare_survival()


func _check_phase_transition(current_ms: float) -> void:
	if _chart_data == null or _current_phase_idx + 1 >= _chart_data.phases.size():
		return
	var next: ChartLoader.PhaseData = _chart_data.phases[_current_phase_idx + 1]
	if current_ms >= next.start_ms:
		_current_phase_idx += 1
		if next.transition_dialogue_path != "" and _transition_runner != null:
			_begin_phase_transition(_current_phase_idx)
		else:
			_apply_phase(_current_phase_idx, current_ms)


func _begin_phase_transition(idx: int) -> void:
	_phase_transition_active = true
	await _music_player.fade_out(0.5)
	_music_player.stop()
	for action in _pending_notes:
		_pending_notes[action].clear()
	_hud.clear_arrows()
	var enemy_sprite := _enemy_battle.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if enemy_sprite != null:
		var tween := create_tween()
		tween.tween_property(enemy_sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.15)
		tween.tween_property(enemy_sprite, "modulate", Color.WHITE, 0.3)
		await tween.finished
	var phase: ChartLoader.PhaseData = _chart_data.phases[idx]
	var data := DialogueLoader.load_json(phase.transition_dialogue_path)
	_transition_runner.play(data, phase.transition_dialogue_id)
	await _transition_runner.dialogue_finished
	# Preparar fase 2 con mini-pre-roll para que las flechas tengan tiempo de caer
	_phase_audio_offset_ms = phase.start_ms
	_metronome.bpm = phase.bpm
	if not phase.audio_path.is_empty():
		var new_stream = load(phase.audio_path)
		if new_stream is AudioStream:
			_music_player.stream = new_stream
	_pre_roll_total_ms = _arrow_travel_ms
	_pre_roll_elapsed_ms = 0.0
	_in_pre_roll = true
	_phase_transition_active = false


func _apply_phase(idx: int, current_ms: float) -> void:
	var phase: ChartLoader.PhaseData = _chart_data.phases[idx]
	_metronome.bpm = phase.bpm
	if not phase.audio_path.is_empty():
		var new_stream = load(phase.audio_path)
		if new_stream is AudioStream:
			_phase_audio_offset_ms = phase.start_ms
			var offset: float = (current_ms - phase.start_ms) / 1000.0
			_music_player.switch_stream(new_stream, offset)
	print("[RHYTHM] Phase %d → BPM %.1f @ %.0fms" % [idx, phase.bpm, current_ms])


func _all_queues_empty() -> bool:
	for action in _pending_notes:
		if not _pending_notes[action].is_empty():
			return false
	return true


func _on_note_expected(note: NoteData) -> void:
	_pending_notes[note.action].append({note = note, hit_ms = note.time_ms})


func _on_button_pressed(action: String) -> void:
	var queue: Array = _pending_notes[action]
	if queue.is_empty():
		if not _in_pre_roll and not _level_ended and not _phase_transition_active:
			_referee.on_spam_press()
		return
	var current_ms: float = _get_current_ms()
	var entry = queue[0]
	if current_ms < entry.hit_ms - _metronome.window_good:
		return
	var timing: String = _metronome.evaluate_timing(current_ms, entry.hit_ms)
	var effective_timing: String
	if timing == "Miss":
		effective_timing = "Miss"
	elif entry.note.is_fake:
		effective_timing = "FakeHit"
	else:
		effective_timing = timing
	_judge.evaluate(action, entry.note, effective_timing)
	queue.pop_front()


func _on_note_result_debug(player_action: String, expected_action: String, timing: String, success: bool) -> void:
	var label: String = "HIT" if success else "MISS"
	print("[RHYTHM] %s | %s | esperada=%s | presionada=%s | t=%.0fms" % [label, timing, expected_action, player_action, _get_current_ms()])


func _on_level_ended(player_won: bool) -> void:
	if _level_ended:
		return
	_level_ended = true
	print("[RHYTHM] Level ended — player_won=%s" % player_won)
	await _music_player.fade_out(maxf(outro_delay_s, 0.3))
	_music_player.stop()
	if player_won:
		Gamemanager.pending_dialogue_result = "win"
		_go_to_post_battle(win_scene_path)
	else:
		Gamemanager.pending_dialogue_result = "lose"
		_go_to_post_battle(lose_scene_path)


func _go_to_post_battle(intermediate_path: String) -> void:
	var target: String = intermediate_path
	if target == "":
		target = Gamemanager.return_scene_path
	if target == "":
		target = fallback_map_scene_path
	if target == "":
		push_warning("Battle: no hay escena destino post-batalla.")
		return
	get_tree().change_scene_to_file(target)
