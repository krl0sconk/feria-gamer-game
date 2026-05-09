# Reglas de vida del jugador editables desde el editor.
class_name HealthRules
extends Resource

## HP máximo e inicial del jugador.
@export var max_player_hp: int = 100
## Daño aplicado al jugador por cada Miss.
@export var miss_damage: int = 10
## Cura opcional al lograr un Perfect (0 = sin cura).
@export var perfect_heal: int = 0
## Cura opcional al lograr un Good (0 = sin cura).
@export var good_heal: int = 0


func get_hp_delta(timing: String) -> int:
	match timing:
		"Perfect": return perfect_heal
		"Good":    return good_heal
		_:         return -miss_damage
