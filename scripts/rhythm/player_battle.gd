extends CharacterBody2D

@onready var anim = $AnimatedSprite2D

func _ready():
	anim.play("idle")

func _process(delta):

	if Input.is_action_just_pressed("ui_left"):
		play_temp("left")

	elif Input.is_action_just_pressed("ui_down"):
		play_temp("down")

	elif Input.is_action_just_pressed("ui_up"):
		play_temp("up")

	elif Input.is_action_just_pressed("ui_right"):
		play_temp("right")


func play_temp(animation_name):
	anim.play(animation_name)
	await anim.animation_finished
	anim.play("idle")
