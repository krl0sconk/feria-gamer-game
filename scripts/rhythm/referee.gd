# Mantiene el estado de la partida (HP, puntuación, combo) y detecta fin de nivel.
class_name Referee
extends Node

signal score_updated(score: int)
signal hp_updated(player_hp: int, enemy_hp: int)
signal combo_updated(combo: int)
# true = jugador ganó, false = jugador perdió
signal level_ended(player_won: bool)

@export var player_hp: int = 100
@export var enemy_hp: int = 100
@export var score: int = 0
@export var combo: int = 0
@export var max_combo: int = 0


func on_note_result(_player_action: String, _expected_action: String, timing: String, success: bool) -> void:
	match timing:
		"Perfect":
			if success:
				enemy_hp -= 20
				score += 300
				combo += 1
		"Good":
			if success:
				enemy_hp -= 10
				score += 100
				combo = 0
		_:
			player_hp -= 10
			combo = 0

	if combo > max_combo:
		max_combo = combo

	score_updated.emit(score)
	hp_updated.emit(player_hp, enemy_hp)
	combo_updated.emit(combo)
	_check_level_end()


func _check_level_end() -> void:
	if enemy_hp <= 0:
		level_ended.emit(true)
	elif player_hp <= 0:
		level_ended.emit(false)
