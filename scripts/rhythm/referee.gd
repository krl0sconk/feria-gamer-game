# Mantiene el estado de la partida (HP, score, combo) y detecta fin de nivel.
# Data-driven: toda la sintonía se hace mediante los Resources ScoreRules y HealthRules
# asignados desde el Inspector, siguiendo OCP y DIP.
class_name Referee
extends Node

signal score_updated(score: int)
signal player_hp_updated(hp: int, max_hp: int)
signal combo_updated(combo: int, max_combo: int)
# true = jugador sobrevivió, false = jugador cayó
signal level_ended(player_won: bool)

@export var score_rules: ScoreRules
@export var health_rules: HealthRules

var _player_hp: int = 0
var _score: int = 0
var _combo: int = 0
var _max_combo: int = 0
var _level_over: bool = false


func _ready() -> void:
	if health_rules == null:
		push_error("Referee: falta asignar 'health_rules' (HealthRules) en el Inspector.")
		return
	if score_rules == null:
		push_error("Referee: falta asignar 'score_rules' (ScoreRules) en el Inspector.")
		return
	_player_hp = health_rules.max_player_hp
	_emit_all()


# Callback conectado a Judge.note_result.
func on_note_result(_player_action: String, _expected_action: String, timing: String, success: bool) -> void:
	if _level_over:
		return
	var t := timing if success else "Miss"
	if t != "Miss":
		_combo += 1
		if _combo > _max_combo:
			_max_combo = _combo
	else:
		_combo = 0
	_score = max(_score + score_rules.calculate_points(t, _combo), score_rules.min_score)
	_player_hp = clamp(_player_hp + health_rules.get_hp_delta(t), 0, health_rules.max_player_hp)
	_emit_all()
	_check_defeat()


# Lo llama Battle cuando la canción termina y el jugador sigue vivo.
func declare_survival() -> void:
	if _level_over:
		return
	_level_over = true
	level_ended.emit(true)


func _emit_all() -> void:
	score_updated.emit(_score)
	player_hp_updated.emit(_player_hp, health_rules.max_player_hp)
	combo_updated.emit(_combo, _max_combo)


func _check_defeat() -> void:
	if _player_hp <= 0 and not _level_over:
		_level_over = true
		level_ended.emit(false)
