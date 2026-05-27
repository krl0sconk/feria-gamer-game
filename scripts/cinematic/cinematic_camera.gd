# Control de cámara 2D durante cinemáticas (pan/zoom/restore/shake).
class_name CinematicCamera
extends RefCounted

static var _saved: Dictionary = {}
static var _active_tween: Tween = null


static func _kill_active_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


static func find_camera(tree: SceneTree) -> Camera2D:
	if tree == null:
		return null
	var player := tree.get_first_node_in_group("player")
	if player != null:
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		if cam != null:
			return cam
	return tree.root.get_viewport().get_camera_2d()


static func save_state(camera: Camera2D) -> void:
	if camera == null:
		return
	if not _saved.is_empty():
		return
	_saved = {
		"position": camera.position,
		"offset": camera.offset,
		"zoom": camera.zoom,
	}


static func focus_on(owner: Node, target: Node2D, duration: float, zoom_value: float) -> void:
	var tree := owner.get_tree()
	var camera := find_camera(tree)
	var player := tree.get_first_node_in_group("player") as Node2D
	if camera == null or player == null or target == null:
		push_warning("CinematicCamera: focus_on — cámara, player o target no encontrado.")
		return

	save_state(camera)
	var dest := player.to_local(target.global_position)
	_kill_active_tween()
	var tween := owner.create_tween()
	_active_tween = tween
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "position", dest, duration)
	if zoom_value > 0.0:
		tween.tween_property(camera, "zoom", Vector2.ONE * zoom_value, duration)
	await tween.finished
	_active_tween = null


static func release(owner: Node, duration: float) -> void:
	var camera := find_camera(owner.get_tree())
	if camera == null or _saved.is_empty():
		return

	_kill_active_tween()
	var tween := owner.create_tween()
	_active_tween = tween
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "position", _saved.position, duration)
	tween.tween_property(camera, "offset", _saved.offset, duration)
	tween.tween_property(camera, "zoom", _saved.zoom, duration)
	await tween.finished
	_saved.clear()
	_active_tween = null


static func reset_immediate(tree: SceneTree) -> void:
	_kill_active_tween()
	var camera := find_camera(tree)
	if camera == null:
		_saved.clear()
		return
	if _saved.is_empty():
		camera.offset = Vector2.ZERO
		return
	camera.position = _saved.position
	camera.offset = _saved.offset
	camera.zoom = _saved.zoom
	_saved.clear()


static func shake(owner: Node, intensity: float, duration: float, should_continue: Callable) -> void:
	var camera := find_camera(owner.get_tree())
	if camera == null:
		return

	var base_offset: Vector2 = camera.offset
	var elapsed := 0.0
	var step := 0.03
	while elapsed < duration:
		if should_continue.is_valid() and not bool(should_continue.call()):
			break
		camera.offset = base_offset + Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		await owner.get_tree().create_timer(step).timeout
		elapsed += step
	camera.offset = base_offset
