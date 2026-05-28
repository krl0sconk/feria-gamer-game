extends CharacterBody2D

const PLAYER_BATTLE_PJ1: SpriteFrames = preload("res://assets/images/characters/pj1/pj1_battle.tres")
const PLAYER_BATTLE_PJ2: SpriteFrames = preload("res://assets/images/characters/pj2/pj2_battle.tres")
const PLAYER_BATTLE_PJ3: SpriteFrames = preload("res://assets/images/characters/pj3/pj3_battle.tres")
const PLAYER_BATTLE_PJ4: SpriteFrames = preload("res://assets/images/characters/pj4/pj4_battle.tres")

# Misma escala para los 4 personajes — sus spritesheets tienen el mismo
# tamaño de frame, así que renderizan al mismo tamaño visual.
const BATTLE_SCALE := Vector2(0.25, 0.25)

const BATTLE_ANIMS := {
	"note_left": &"left",
	"note_down": &"down",
	"note_up": &"up",
	"note_right": &"right",
}

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _idle_anim: StringName = &"idle"


func _ready() -> void:
	var skin_key := Gamemanager.selectedskin.strip_edges().to_lower().replace(" ", "")
	match skin_key:
		"idlepj4":
			anim.sprite_frames = PLAYER_BATTLE_PJ4
		"idlepj3":
			anim.sprite_frames = PLAYER_BATTLE_PJ3
		"idlepj2":
			anim.sprite_frames = PLAYER_BATTLE_PJ2
		_:
			anim.sprite_frames = PLAYER_BATTLE_PJ1
	anim.scale = BATTLE_SCALE
	_play_idle()
	if not anim.animation_finished.is_connected(_on_animation_finished):
		anim.animation_finished.connect(_on_animation_finished)
	var input_node := get_parent().get_node_or_null("PlayerInput")
	if input_node != null and input_node.has_signal("button_pressed"):
		var cb := Callable(self, "_play_for_action")
		if not input_node.button_pressed.is_connected(cb):
			input_node.button_pressed.connect(cb)


func _play_for_action(action: String) -> void:
	var anim_name: StringName = BATTLE_ANIMS.get(action, &"idle")
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim_name):
		return
	anim.flip_h = false
	anim.play(anim_name)
	if anim.sprite_frames.get_frame_count(anim_name) <= 1:
		# Una sola pose estática: volver a idle tras un instante.
		var timer := get_tree().create_timer(0.12)
		timer.timeout.connect(_play_idle, CONNECT_ONE_SHOT)


func _play_idle() -> void:
	if anim.sprite_frames == null:
		return
	anim.flip_h = false
	if anim.sprite_frames.has_animation(&"idle"):
		_idle_anim = &"idle"
	elif anim.sprite_frames.has_animation(&"Idle"):
		_idle_anim = &"Idle"
	else:
		var names := anim.sprite_frames.get_animation_names()
		if names.is_empty():
			return
		_idle_anim = names[0]
	anim.play(_idle_anim)


func _on_animation_finished() -> void:
	if anim.animation != _idle_anim:
		_play_idle()
