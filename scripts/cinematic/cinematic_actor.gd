# Helpers de movimiento y animación para comandos de cinemática.
class_name CinematicActor
extends RefCounted


static func find_sprite(actor: Node) -> AnimatedSprite2D:
	if actor is AnimatedSprite2D:
		return actor as AnimatedSprite2D
	if actor == null:
		return null
	var named := actor.get_node_or_null("AnimatedSprite2D")
	if named is AnimatedSprite2D:
		return named as AnimatedSprite2D
	named = actor.get_node_or_null("Sprite2D")
	if named is AnimatedSprite2D:
		return named as AnimatedSprite2D
	for child in actor.find_children("*", "AnimatedSprite2D", false, false):
		return child as AnimatedSprite2D
	return null


static func infer_direction(from_pos: Vector2, to_pos: Vector2) -> String:
	var delta := to_pos - from_pos
	if absf(delta.x) >= absf(delta.y):
		return "right" if delta.x >= 0.0 else "left"
	return "down" if delta.y >= 0.0 else "up"


static func apply_facing(sprite: AnimatedSprite2D, direction: String, anim_base: String = "walk") -> void:
	if sprite == null:
		return
	var dir_lower := direction.to_lower()
	var anim_name := _pick_walk_animation(sprite, dir_lower, anim_base)
	if not anim_name.is_empty():
		sprite.play(anim_name)
	if dir_lower == "left":
		sprite.flip_h = true
	elif dir_lower == "right":
		sprite.flip_h = false


static func play_idle(sprite: AnimatedSprite2D, idle_base: String = "idle") -> void:
	if sprite == null:
		return
	var anim_name := _pick_animation(sprite, [
		idle_base,
		idle_base.capitalize(),
		"Idle",
		"idle",
	])
	if not anim_name.is_empty():
		sprite.play(anim_name)


static func walk_node_to(
	owner: Node,
	actor: Node2D,
	destination: Vector2,
	speed: float,
	duration_override: float,
	walk_animation: String,
	idle_animation: String,
	face_direction: bool
) -> void:
	if actor == null or owner == null:
		return
	var sprite := find_sprite(actor)
	var from_pos: Vector2 = actor.global_position
	var distance: float = from_pos.distance_to(destination)
	if distance < 1.0:
		play_idle(sprite, idle_animation)
		return

	var duration: float
	if duration_override > 0.0:
		duration = duration_override
	else:
		duration = distance / maxf(speed, 1.0)

	if face_direction:
		apply_facing(sprite, infer_direction(from_pos, destination), walk_animation)

	var tween := owner.create_tween()
	tween.tween_property(actor, "global_position", destination, duration)
	await tween.finished
	play_idle(sprite, idle_animation)


static func face_toward(sprite: AnimatedSprite2D, from_pos: Vector2, to_pos: Vector2, idle_base: String = "idle") -> void:
	if sprite == null:
		return
	var direction := infer_direction(from_pos, to_pos)
	if direction == "left":
		sprite.flip_h = true
	elif direction == "right":
		sprite.flip_h = false
	play_idle(sprite, idle_base)


static func play_animation_on(
	_owner: Node,
	actor: Node,
	animation: String,
	wait_finish: bool,
	idle_animation: String = "idle"
) -> void:
	var sprite: AnimatedSprite2D = null
	if actor is AnimatedSprite2D:
		sprite = actor as AnimatedSprite2D
	else:
		sprite = find_sprite(actor)
	if sprite == null:
		var label: String = str(actor.get_path()) if actor != null else "?"
		push_warning("CinematicActor: sin AnimatedSprite2D en '%s'." % label)
		return
	var anim_name := _pick_animation(sprite, [animation, animation.capitalize()])
	if anim_name.is_empty():
		push_warning("CinematicActor: animación '%s' no encontrada." % animation)
		return
	sprite.play(anim_name)
	if not wait_finish:
		return
	if sprite.sprite_frames.get_animation_loop(anim_name):
		push_warning("CinematicActor: '%s' es loop — wait_finish ignorado." % anim_name)
		return
	await sprite.animation_finished
	play_idle(sprite, idle_animation)


static func set_collision_enabled(node: Node, enabled: bool) -> void:
	if node == null:
		return
	if node is CollisionShape2D:
		(node as CollisionShape2D).disabled = not enabled
		return
	if node is CollisionPolygon2D:
		(node as CollisionPolygon2D).disabled = not enabled
		return
	if node is StaticBody2D or node is CharacterBody2D or node is Area2D:
		for child in node.find_children("*", "CollisionShape2D", false, false):
			(child as CollisionShape2D).disabled = not enabled


static func _pick_walk_animation(sprite: AnimatedSprite2D, direction: String, base: String) -> String:
	return _pick_animation(sprite, [
		"%s_%s" % [base, direction],
		"%s%s" % [base, direction.capitalize()],
		"Walk_%s" % direction.capitalize(),
		"walk_%s" % direction,
		base,
		base.capitalize(),
		"Walk",
		"walk",
	])


static func _pick_animation(sprite: AnimatedSprite2D, candidates: Array) -> String:
	if sprite == null or sprite.sprite_frames == null:
		return ""
	for raw in candidates:
		var name := str(raw)
		if sprite.sprite_frames.has_animation(name):
			return name
	return ""
