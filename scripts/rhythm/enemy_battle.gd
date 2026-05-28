extends CharacterBody2D

@export var preferred_animation: String = "Enemy"

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_start_animation()


func _start_animation() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var anim_name := preferred_animation
	if not _sprite.sprite_frames.has_animation(anim_name):
		var names := _sprite.sprite_frames.get_animation_names()
		if names.is_empty():
			return
		anim_name = names[0]
	if _sprite.is_playing() and _sprite.animation == anim_name:
		return
	_sprite.play(anim_name)
