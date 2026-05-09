# Reglas de puntuación editables desde el editor.
# Se asigna al Referee como Resource para permitir presets de dificultad (.tres).
class_name ScoreRules
extends Resource

## Puntos otorgados al acertar una nota con timing "Perfect".
@export var perfect_points: int = 300
## Puntos otorgados al acertar una nota con timing "Good".
@export var good_points: int = 100
## Puntos aplicados en un Miss (negativo para restar).
@export var miss_points: int = -50
## Bonus extra por hit: se suma (combo_actual * este valor) en cada acierto.
@export var combo_bonus_per_hit: int = 10
## Piso del score: nunca baja de este valor.
@export var min_score: int = 0


func calculate_points(timing: String, combo: int) -> int:
	match timing:
		"Perfect": return perfect_points + combo * combo_bonus_per_hit
		"Good":    return good_points    + combo * combo_bonus_per_hit
		_:         return miss_points
