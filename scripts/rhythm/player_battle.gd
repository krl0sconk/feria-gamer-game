extends CharacterBody2D

const PLAYER_BATTLE_PJ1: SpriteFrames = preload("res://assets/images/characters/pj1/pj1_battle.tres")
const PLAYER_BATTLE_PJ2: SpriteFrames = preload("res://assets/images/characters/pj2/pj2_battle.tres")
const PLAYER_BATTLE_PJ4: SpriteFrames = preload("res://assets/images/characters/pj4/pj4_battle.tres")

@onready var anim = $AnimatedSprite2D


func _ready():
	var skin := Gamemanager.selectedskin.strip_edges().to_lower().replace(" ", "")
	if skin == "idlepj4":
		anim.sprite_frames = PLAYER_BATTLE_PJ4
	elif skin == "idlepj2" or skin == "idlepj3":
		anim.sprite_frames = PLAYER_BATTLE_PJ2
	else:
		anim.sprite_frames = PLAYER_BATTLE_PJ1
	if anim.sprite_frames.has_animation("idle"):
		anim.play("idle")
	elif anim.sprite_frames.has_animation("Idle"):
		anim.play("Idle")
