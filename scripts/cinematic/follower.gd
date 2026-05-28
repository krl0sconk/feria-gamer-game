# Componente de NPC líder/seguidor. Colócalo como hijo de un CharacterBody2D o Node2D.
@tool
class_name Follower
extends Node2D

const ActorHelper = preload("res://scripts/cinematic/cinematic_actor.gd")

enum State { IDLE, LEAD, FOLLOW, PAUSED }

signal route_completed
signal waypoint_reached(index: int)

@export var target_path: NodePath
@export var path_node: NodePath:
	set(value):
		path_node = value
		queue_redraw()

@export var speed: float = 110.0
@export var arrival_distance: float = 16.0
@export var wait_distance: float = 96.0
@export var animation_walk: String = "walk"
@export var animation_idle: String = "idle"

@export var editor_route_color: Color = Color(0.95, 0.55, 1.0, 0.85):
	set(value):
		editor_route_color = value
		queue_redraw()

var _state: State = State.IDLE
var _paused_state: State = State.IDLE
var _waypoints: Array[Vector2] = []
var _waypoint_index: int = 0
var _follow_target: Node2D = null
var _waiting_for_player: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	set_process(false)
	set_physics_process(false)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func lead_along(path_node_path: NodePath) -> void:
	var actor := _actor()
	if actor == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var route := scene.get_node_or_null(path_node_path)
	if route == null or not route.has_method("get_waypoints"):
		push_warning("Follower: path_node '%s' inválido o sin get_waypoints()." % str(path_node_path))
		route_completed.emit()
		return

	_waypoints = route.call("get_waypoints")
	if _waypoints.is_empty():
		push_warning("Follower: path_node '%s' no tiene waypoints." % str(path_node_path))
		route_completed.emit()
		return
	_waypoint_index = 0
	_waiting_for_player = false
	_follow_target = null
	_state = State.LEAD
	set_physics_process(true)


func follow(target: Node2D) -> void:
	if target == null:
		push_warning("Follower: follow() con target null.")
		return
	_follow_target = target
	_waypoints.clear()
	_waypoint_index = 0
	_waiting_for_player = false
	_state = State.FOLLOW
	set_physics_process(true)


func pause() -> void:
	if _state == State.IDLE or _state == State.PAUSED:
		return
	_paused_state = _state
	_state = State.PAUSED
	_play_idle()


func resume() -> void:
	if _state != State.PAUSED:
		return
	_state = _paused_state
	set_physics_process(_state != State.IDLE)


func stop() -> void:
	_state = State.IDLE
	_paused_state = State.IDLE
	_waypoints.clear()
	_waypoint_index = 0
	_follow_target = null
	_waiting_for_player = false
	set_physics_process(false)
	_play_idle()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	match _state:
		State.LEAD:
			_process_lead(delta)
		State.FOLLOW:
			_process_follow(delta)


func _process_lead(delta: float) -> void:
	if _waypoints.is_empty() or _waypoint_index >= _waypoints.size():
		_finish_route()
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var actor := _actor()
		if actor != null:
			var dist_to_player := actor.global_position.distance_to(player.global_position)
			if dist_to_player > wait_distance:
				_waiting_for_player = true
				_play_idle()
				return
			if _waiting_for_player:
				_waiting_for_player = false

	var target := _waypoints[_waypoint_index]
	if _move_toward(target, delta):
		waypoint_reached.emit(_waypoint_index)
		_waypoint_index += 1
		if _waypoint_index >= _waypoints.size():
			_finish_route()


func _process_follow(delta: float) -> void:
	if _follow_target == null or not is_instance_valid(_follow_target):
		stop()
		return
	_move_toward(_follow_target.global_position, delta, true)


func _move_toward(target: Vector2, delta: float, stop_at_target: bool = true) -> bool:
	var actor := _actor()
	if actor == null:
		return true

	var current := actor.global_position
	var to_target := target - current
	var distance := to_target.length()
	if distance <= arrival_distance:
		if stop_at_target:
			_set_actor_position(target)
		_play_idle()
		return true

	var direction := to_target.normalized()
	var step := speed * delta
	var next_pos := target if step >= distance else current + direction * step
	_set_actor_position(next_pos)

	var sprite := ActorHelper.find_sprite(actor)
	ActorHelper.apply_facing(sprite, ActorHelper.infer_direction(current, target), animation_walk)
	return false


func _set_actor_position(global_pos: Vector2) -> void:
	var actor := _actor()
	if actor == null:
		return
	if actor is CharacterBody2D:
		var body := actor as CharacterBody2D
		body.velocity = Vector2.ZERO
		body.global_position = global_pos
		body.move_and_slide()
	else:
		actor.global_position = global_pos


func _finish_route() -> void:
	_state = State.IDLE
	set_physics_process(false)
	_play_idle()
	route_completed.emit()


func _play_idle() -> void:
	var actor := _actor()
	if actor == null:
		return
	var sprite := ActorHelper.find_sprite(actor)
	ActorHelper.play_idle(sprite, animation_idle)


func _actor() -> Node2D:
	var parent := get_parent()
	if parent is Node2D:
		return parent as Node2D
	push_warning("Follower '%s': el padre debe ser Node2D/CharacterBody2D." % name)
	return null


func _draw() -> void:
	if not Engine.is_editor_hint() or path_node.is_empty():
		return

	var actor := _actor()
	if actor == null:
		return

	var scene := get_tree().edited_scene_root
	if scene == null:
		return

	var route := scene.get_node_or_null(path_node)
	if route == null or not route.has_method("get_waypoints"):
		return

	var points: Array[Vector2] = route.call("get_waypoints")
	if points.is_empty():
		return

	var local_points: PackedVector2Array = PackedVector2Array()
	for point in points:
		local_points.append(to_local(point))

	var start := to_local(actor.global_position)
	if local_points.size() >= 1:
		draw_line(start, local_points[0], editor_route_color, 2.0)
	for i in range(local_points.size() - 1):
		draw_line(local_points[i], local_points[i + 1], editor_route_color, 2.0)
	for i in range(local_points.size()):
		draw_circle(local_points[i], 4.0, editor_route_color)
