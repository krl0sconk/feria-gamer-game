extends CharacterBody2D


const SPEED = 300.0
var  movimiento = PlayerInput
var skin = null 


func _physics_process(delta) -> void :
	var direction = Vector2.ZERO
	direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	direction.y = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	velocity = direction.normalized() * SPEED	
	move_and_slide()
	print(direction)
	print(position)
	
