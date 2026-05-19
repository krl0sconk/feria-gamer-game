extends CharacterBody2D

const SPEED := 300.0
const FOOTSTEPS_PATH := "res://assets/audio/sfx/footsteps2.wav"
const SKIN_FRAMES := {
	"idle (1)": preload("res://assets/images/sprites/walkUpj1.tres"),
	"idle pj2": preload("res://assets/images/sprites/walkUpj1.tres")
}

## Controlado externamente por el Map (p. ej. DialogueRunner.dialogue_started
## → `disable_movement`). Cuando es false, el Player ignora input y se detiene.
var can_move: bool = true
var _is_walking: bool = false

@onready var _footsteps_player: AudioStreamPlayer = _create_footsteps_player()


func _ready() -> void:
	add_to_group("player")
	set_skin(Gamemanager.selectedskin)
	if Gamemanager.has_loaded_position:
		global_position = Gamemanager.consume_loaded_position()


func _physics_process(_delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		_set_walking(false)
		move_and_slide()
		return
	var direction := Vector2.ZERO
	direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	velocity = direction.normalized() * SPEED
	_set_walking(velocity != Vector2.ZERO)
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


func _create_footsteps_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = "FootstepsPlayer"
	player.stream = load(FOOTSTEPS_PATH) as AudioStream
	player.volume_db = -8.5
	player.finished.connect(_on_footsteps_finished)
	if AudioServer.get_bus_index(&"SFX") != -1:
		player.bus = &"SFX"
	add_child(player)
	return player


func _set_walking(walking: bool) -> void:
	if _is_walking == walking:
		return
	_is_walking = walking
	if _footsteps_player == null:
		return
	if _is_walking:
		if not _footsteps_player.playing:
			_footsteps_player.play()
	else:
		_footsteps_player.stop()


func _on_footsteps_finished() -> void:
	if _is_walking and _footsteps_player != null:
		_footsteps_player.play()
