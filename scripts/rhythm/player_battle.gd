extends CharacterBody2D

const PLAYER_BATTLE_PJ1: SpriteFrames = preload("res://assets/images/characters/pj1/pj1_battle.tres")
const PLAYER_BATTLE_PJ2: SpriteFrames = preload("res://assets/images/characters/pj2/pj2_battle.tres")
const PLAYER_BATTLE_PJ3: SpriteFrames = preload("res://assets/images/characters/pj3/pj3_battle.tres")
const PLAYER_BATTLE_PJ4: SpriteFrames = preload("res://assets/images/characters/pj4/pj4_battle.tres")
const PLAYER_WALK_PJ2: SpriteFrames = preload("res://assets/images/characters/pj2/pj2_walk.tres")
const PLAYER_WALK_PJ3: SpriteFrames = preload("res://assets/images/characters/pj3/pj3_walk.tres")
const PLAYER_WALK_PJ4: SpriteFrames = preload("res://assets/images/characters/pj4/pj4_walk.tres")

const BATTLE_SCALE := Vector2(0.25, 0.25)
const WALK_BATTLE_SCALE := Vector2(16.0, 16.0)
const WALK_NOTE_HOLD_S := 0.12

const NOTE_ACTIONS: Array[String] = ["note_left", "note_down", "note_up", "note_right"]

const BATTLE_ANIMS := {
	"note_left": &"left",
	"note_down": &"down",
	"note_up": &"up",
	"note_right": &"right",
}

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _skin_key := ""
var _battle_frames: SpriteFrames
var _walk_frames: SpriteFrames
var _uses_walk_fallback := false
var _idle_anim: StringName = &"idle"


func _ready() -> void:
	_skin_key = Gamemanager.selectedskin.strip_edges().to_lower().replace(" ", "")
	match _skin_key:
		"idlepj4":
			_apply_skin(PLAYER_BATTLE_PJ4, PLAYER_WALK_PJ4)
		"idlepj3":
			_apply_skin(PLAYER_BATTLE_PJ3, PLAYER_WALK_PJ3)
		"idlepj2":
			_apply_skin(PLAYER_BATTLE_PJ2, PLAYER_WALK_PJ2)
		_:
			_apply_skin(PLAYER_BATTLE_PJ1, null)
	_play_idle()
	if not anim.animation_finished.is_connected(_on_animation_finished):
		anim.animation_finished.connect(_on_animation_finished)


func _apply_skin(battle_frames: SpriteFrames, walk_frames: SpriteFrames) -> void:
	_battle_frames = battle_frames
	_walk_frames = walk_frames
	_uses_walk_fallback = walk_frames != null and not _has_battle_directionals(battle_frames)
	_use_battle_frames()


func _use_battle_frames() -> void:
	if _battle_frames != null:
		anim.sprite_frames = _battle_frames
		anim.scale = BATTLE_SCALE
	elif _walk_frames != null:
		anim.sprite_frames = _walk_frames
		anim.scale = WALK_BATTLE_SCALE


func _has_battle_directionals(frames: SpriteFrames) -> bool:
	if frames == null:
		return false
	return frames.has_animation(&"left") or frames.has_animation(&"right")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	for action in NOTE_ACTIONS:
		if event.is_action_pressed(action):
			_play_for_action(action)
			return


func _play_for_action(action: String) -> void:
	if _uses_walk_fallback:
		_play_walk_action(action)
		return
	var anim_name: StringName = BATTLE_ANIMS.get(action, &"idle")
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim_name):
		return
	_use_battle_frames()
	anim.flip_h = false
	anim.play(anim_name)


func _play_walk_action(action: String) -> void:
	if _walk_frames == null:
		return
	anim.sprite_frames = _walk_frames
	anim.scale = WALK_BATTLE_SCALE
	match action:
		"note_left":
			anim.flip_h = _skin_key != "idlepj4"
			if anim.sprite_frames.has_animation(&"walk_side"):
				anim.play(&"walk_side")
		"note_right":
			anim.flip_h = _skin_key == "idlepj4"
			if anim.sprite_frames.has_animation(&"walk_side"):
				anim.play(&"walk_side")
		"note_up":
			anim.flip_h = false
			if anim.sprite_frames.has_animation(&"walk_up"):
				anim.play(&"walk_up")
		"note_down":
			anim.flip_h = false
			if anim.sprite_frames.has_animation(&"walk_down"):
				anim.play(&"walk_down")
	var timer := get_tree().create_timer(WALK_NOTE_HOLD_S)
	timer.timeout.connect(_return_to_battle_idle)


func _return_to_battle_idle() -> void:
	if not _uses_walk_fallback:
		return
	_use_battle_frames()
	_play_idle()


func _play_idle() -> void:
	if _battle_frames != null:
		_use_battle_frames()
	elif _walk_frames != null:
		anim.sprite_frames = _walk_frames
		anim.scale = WALK_BATTLE_SCALE
	if anim.sprite_frames == null:
		return
	anim.flip_h = false
	if _battle_frames != null and anim.sprite_frames.has_animation(&"idle"):
		_idle_anim = &"idle"
	elif _battle_frames != null and anim.sprite_frames.has_animation(&"Idle"):
		_idle_anim = &"Idle"
	elif _uses_walk_fallback and anim.sprite_frames.has_animation(&"walk_down"):
		_idle_anim = &"walk_down"
		anim.frame = 0
	else:
		var names := anim.sprite_frames.get_animation_names()
		if names.is_empty():
			return
		_idle_anim = names[0]
	anim.play(_idle_anim)


func _on_animation_finished() -> void:
	if _uses_walk_fallback:
		return
	if anim.animation != _idle_anim:
		_play_idle()
