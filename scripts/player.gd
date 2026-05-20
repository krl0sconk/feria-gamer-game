extends CharacterBody2D

const SPEED := 300.0
const FOOTSTEPS_PATH := "res://assets/audio/sfx/footsteps2.wav"
const WALK_UP_PJ1: SpriteFrames = preload("res://assets/images/sprites/walkUpj1.tres")
const WALK_DOWN_PJ1: SpriteFrames = preload("res://assets/images/sprites/walkDownpj1.tres")
const WALK_SIDE_PJ1: SpriteFrames = preload("res://assets/images/sprites/walkSidepj1.tres")
const WALK_STATIC_PJ2: SpriteFrames = preload("res://assets/images/sprites/walkstaticpj2.tres")
const WALK_DOWN_PJ2: SpriteFrames = preload("res://assets/images/sprites/walkdownpj2.tres")
const SKIN_FRAMES := {
	"idle (1)": preload("res://assets/images/sprites/walkUpj1.tres"),
	"idle pj2": preload("res://assets/images/sprites/walkstaticpj2.tres"),
	"idlepj2": preload("res://assets/images/sprites/walkstaticpj2.tres")
}

## Controlado externamente por el Map (p. ej. DialogueRunner.dialogue_started
## → `disable_movement`). Cuando es false, el Player ignora input y se detiene.
var can_move: bool = true
var _is_walking: bool = false
var _uses_pj1_directional_walk: bool = false
var _uses_pj2_down_walk: bool = false
var _facing_dir: String = "up"

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
	direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	velocity = direction.normalized() * SPEED
	_set_walking(velocity != Vector2.ZERO)
	_update_walk_animation(direction)
	move_and_slide()


func set_skin(skinname: String) -> void:
	var frames: SpriteFrames = null
	var normalized_skin := skinname.strip_edges().to_lower().replace(" ", "")
	if skinname == "idle pj2" or skinname == "idlepj2" or normalized_skin == "idlepj2":
		_uses_pj1_directional_walk = false
		_uses_pj2_down_walk = true
		var pj2_tres := "res://assets/images/sprites/walkstaticpj2.tres"
		if FileAccess.file_exists(pj2_tres):
			frames = load(pj2_tres) as SpriteFrames
		else:
			frames = load("res://assets/images/sprites/idle.tres") as SpriteFrames
	elif SKIN_FRAMES.has(skinname):
		_uses_pj1_directional_walk = true
		_uses_pj2_down_walk = false
		frames = SKIN_FRAMES[skinname]
	else:
		_uses_pj1_directional_walk = true
		_uses_pj2_down_walk = false
		frames = SKIN_FRAMES["idle (1)"]
	if frames != null:
		$Animated.sprite_frames = frames
		$Animated.flip_h = false
		if frames.has_animation("Idle"):
			$Animated.play("Idle")
		elif frames.has_animation("idle"):
			$Animated.play("idle")
		else:
			var names: Array = frames.get_animation_names()
			if names.size() > 0:
				$Animated.play(names[0])


func _update_walk_animation(direction: Vector2) -> void:
	if _uses_pj2_down_walk:
		if direction.y > 0.0:
			$Animated.sprite_frames = WALK_DOWN_PJ2
			if $Animated.sprite_frames.has_animation("default"):
				$Animated.play("default")
			return
		$Animated.sprite_frames = WALK_STATIC_PJ2
		if not direction == Vector2.ZERO and $Animated.sprite_frames.has_animation("default"):
			$Animated.play("default")
		else:
			$Animated.stop()
			$Animated.frame = 0
		return

	if not _uses_pj1_directional_walk:
		return

	var moving: bool = direction != Vector2.ZERO
	if moving:
		if absf(direction.x) > absf(direction.y):
			_facing_dir = "side"
			$Animated.sprite_frames = WALK_SIDE_PJ1
			$Animated.flip_h = direction.x < 0.0
		elif direction.y < 0.0:
			_facing_dir = "up"
			$Animated.sprite_frames = WALK_DOWN_PJ1
			$Animated.flip_h = false
		else:
			_facing_dir = "down"
			$Animated.sprite_frames = WALK_UP_PJ1
			$Animated.flip_h = false
		if $Animated.sprite_frames.has_animation("default"):
			$Animated.play("default")
	else:
		match _facing_dir:
			"side":
				$Animated.sprite_frames = WALK_SIDE_PJ1
			"down":
				$Animated.sprite_frames = WALK_UP_PJ1
			_:
				$Animated.sprite_frames = WALK_DOWN_PJ1
		if $Animated.sprite_frames.has_animation("default"):
			$Animated.stop()
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
