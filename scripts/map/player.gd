extends CharacterBody2D

const SPEED := 300.0
const FOOTSTEPS_PATH := "res://assets/audio/sfx/footsteps2.wav"
const PLAYER_MAP_PJ1: SpriteFrames = preload("res://assets/images/characters/pj1/pj1_walk.tres")
const PLAYER_MAP_PJ2: SpriteFrames = preload("res://assets/images/characters/pj2/pj2_walk.tres")
const PLAYER_MAP_PJ3: SpriteFrames = preload("res://assets/images/characters/pj3/pj3_walk.tres")
const PLAYER_MAP_PJ4: SpriteFrames = preload("res://assets/images/characters/pj4/pj4_walk.tres")
const SKIN_MAP := {
	"idle (1)": "pj1",
	"idle pj2": "pj2",
	"idlepj2": "pj2",
	"idle pj3": "pj3",
	"idlepj3": "pj3",
	"idle pj4": "pj4",
	"idlepj4": "pj4",
}
const SKIN_FRAMES := {
	"idle (1)": PLAYER_MAP_PJ1,
	"idle pj2": PLAYER_MAP_PJ2,
	"idlepj2": PLAYER_MAP_PJ2,
	"idle pj3": PLAYER_MAP_PJ3,
	"idlepj3": PLAYER_MAP_PJ3,
	"idle pj4": PLAYER_MAP_PJ4,
	"idlepj4": PLAYER_MAP_PJ4,
}

## Controlado externamente por el Map (p. ej. DialogueRunner.dialogue_started
## → `disable_movement`). Cuando es false, el Player ignora input y se detiene.
var can_move: bool = true
var _is_walking: bool = false
var _skin_id: String = "pj1"
var _facing_dir: String = "down"

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
		_update_walk_animation(Vector2.ZERO)
		move_and_slide()
		return
	var direction := Vector2.ZERO
	direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	velocity = direction.normalized() * SPEED
	_set_walking(velocity != Vector2.ZERO)
	_update_walk_animation(direction)
	move_and_slide()


func set_skin(skinname: String) -> void:
	var normalized_skin := skinname.strip_edges().to_lower().replace(" ", "")
	_skin_id = SKIN_MAP.get(normalized_skin, SKIN_MAP.get(skinname, "pj1"))
	var frames: SpriteFrames = SKIN_FRAMES.get(skinname, SKIN_FRAMES.get(normalized_skin, SKIN_FRAMES["idle (1)"]))
	if frames != null:
		$Animated.sprite_frames = frames
		$Animated.flip_h = false
		if frames.has_animation("Idle"):
			$Animated.play("Idle")
		elif frames.has_animation("idle"):
			$Animated.play("idle")
		elif frames.has_animation("walk_down"):
			$Animated.play("walk_down")
		elif frames.has_animation("default"):
			$Animated.play("default")
		else:
			var names: Array = frames.get_animation_names()
			if names.size() > 0:
				$Animated.play(names[0])


func _update_walk_animation(direction: Vector2) -> void:
	var moving: bool = direction != Vector2.ZERO

	if _skin_id == "pj1":
		if moving:
			if absf(direction.x) > absf(direction.y):
				_facing_dir = "side"
				$Animated.flip_h = direction.x < 0.0
				if $Animated.sprite_frames.has_animation("walk_side"):
					$Animated.play("walk_side")
			elif direction.y < 0.0:
				_facing_dir = "up"
				$Animated.flip_h = false
				if $Animated.sprite_frames.has_animation("walk_up"):
					$Animated.play("walk_up")
			else:
				_facing_dir = "down"
				$Animated.flip_h = false
				if $Animated.sprite_frames.has_animation("walk_down"):
					$Animated.play("walk_down")
		else:
			$Animated.flip_h = false
			if $Animated.sprite_frames.has_animation("walk_down"):
				$Animated.stop()
				$Animated.play("walk_down")
				$Animated.frame = 0

	elif _skin_id == "pj2":
		if moving:
			if absf(direction.x) > absf(direction.y):
				_facing_dir = "side"
				$Animated.flip_h = direction.x < 0.0
				if $Animated.sprite_frames.has_animation("walk_side"):
					$Animated.play("walk_side")
			elif direction.y < 0.0:
				_facing_dir = "up"
				$Animated.flip_h = false
				if $Animated.sprite_frames.has_animation("walk_up"):
					$Animated.play("walk_up")
			else:
				_facing_dir = "down"
				$Animated.flip_h = false
				if $Animated.sprite_frames.has_animation("walk_down"):
					$Animated.play("walk_down")
		else:
			$Animated.flip_h = false
			if $Animated.sprite_frames.has_animation("walk_down"):
				$Animated.stop()
				$Animated.play("walk_down")
				$Animated.frame = 0

	elif _skin_id == "pj3":
		if moving:
			if $Animated.sprite_frames.has_animation("default"):
				$Animated.play("default")
		else:
			if $Animated.sprite_frames.has_animation("default"):
				$Animated.stop()
				$Animated.play("default")
				$Animated.frame = 0

	elif _skin_id == "pj4":
		if moving:
			if absf(direction.x) > absf(direction.y):
				_facing_dir = "side"
				$Animated.flip_h = direction.x > 0.0
				if $Animated.sprite_frames.has_animation("walk_side"):
					$Animated.play("walk_side")
			elif direction.y < 0.0:
				_facing_dir = "up"
				$Animated.flip_h = false
				if $Animated.sprite_frames.has_animation("walk_up"):
					$Animated.play("walk_up")
			else:
				_facing_dir = "down"
				$Animated.flip_h = false
				if $Animated.sprite_frames.has_animation("walk_down"):
					$Animated.play("walk_down")
		else:
			$Animated.flip_h = false
			if $Animated.sprite_frames.has_animation("walk_down"):
				$Animated.stop()
				$Animated.play("walk_down")
				$Animated.frame = 0


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
