extends CharacterBody2D

const SPEED := 300.0
const SKIN_FRAMES := {
	"idle (1)": preload("res://assets/images/sprites/idle.tres"),
	"idle pj2": preload("res://assets/images/sprites/idlepj2.tres")
}

## Controlado externamente por el Map (p. ej. DialogueRunner.dialogue_started
## → `disable_movement`). Cuando es false, el Player ignora input y se detiene.
var can_move: bool = true


func _ready() -> void:
	add_to_group("player")
	set_skin(Gamemanager.selectedskin)


func _physics_process(_delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction := Vector2.ZERO
	direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	velocity = direction.normalized() * SPEED
	move_and_slide()


func set_skin(skinname: String) -> void:
	if SKIN_FRAMES.has(skinname):
		$Animated.sprite_frames = SKIN_FRAMES[skinname]
	$Animated.play("Idle")


func disable_movement() -> void:
	can_move = false
	velocity = Vector2.ZERO


func enable_movement() -> void:
	can_move = true
