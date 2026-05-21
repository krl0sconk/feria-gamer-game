extends CharacterBody2D

const PLAYER_BATTLE_PJ1: SpriteFrames = preload("res://assets/images/characters/pj1/player_battle_pj1.tres")
const PLAYER_BATTLE_PJ2: SpriteFrames = preload("res://assets/images/characters/pj2/player_battle_pj2.tres")

@onready var anim = $AnimatedSprite2D


func _ready():
	var skin := Gamemanager.selectedskin.strip_edges().to_lower().replace(" ", "")
	if skin == "idlepj2" or skin == "idlepj2":
		anim.sprite_frames = PLAYER_BATTLE_PJ2
	else:
		anim.sprite_frames = PLAYER_BATTLE_PJ1
	if anim.sprite_frames.has_animation("idle"):
		anim.play("idle")
	elif anim.sprite_frames.has_animation("Idle"):
		anim.play("Idle")
