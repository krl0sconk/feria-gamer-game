# Ruta editable en escena: hijos Marker2D definen waypoints en orden.
@tool
class_name WaypointPath
extends Node2D

@export var loop: bool = false
@export var path_color: Color = Color(0.2, 0.85, 1.0, 0.85)
@export var marker_radius: float = 6.0

var _add_waypoint_toggle: bool = false

@export var add_waypoint: bool:
	get:
		return _add_waypoint_toggle
	set(value):
		if not value:
			return
		_add_waypoint_toggle = false
		if Engine.is_editor_hint():
			_add_waypoint_marker()
		notify_property_list_changed()


func _ready() -> void:
	if Engine.is_editor_hint():
		child_entered_tree.connect(_on_hierarchy_changed)
		child_exiting_tree.connect(_on_hierarchy_changed)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _on_hierarchy_changed(_node: Node = null) -> void:
	queue_redraw()


func get_waypoints(use_global: bool = true) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for child in get_children():
		if child is Marker2D:
			result.append(child.global_position if use_global else child.position)
	return result


func get_waypoint_count() -> int:
	var count := 0
	for child in get_children():
		if child is Marker2D:
			count += 1
	return count


## Llamado por el plugin de editor para añadir un waypoint sin usar el Inspector.
func add_waypoint_from_editor() -> void:
	if not Engine.is_editor_hint():
		return
	_add_waypoint_marker()


func _add_waypoint_marker() -> void:
	var marker := Marker2D.new()
	marker.name = "Waypoint%d" % (get_waypoint_count() + 1)
	var offset := Vector2(64.0, 0.0)
	if get_waypoint_count() > 0:
		var last := _get_last_marker()
		if last != null:
			offset = last.position + Vector2(64.0, 0.0)
	marker.position = offset
	add_child(marker)
	marker.owner = owner if owner != null else get_tree().edited_scene_root
	queue_redraw()


func _get_last_marker() -> Marker2D:
	var last: Marker2D = null
	for child in get_children():
		if child is Marker2D:
			last = child as Marker2D
	return last


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var points: PackedVector2Array = PackedVector2Array()
	for child in get_children():
		if child is Marker2D:
			points.append((child as Marker2D).position)

	if points.size() < 2:
		if points.size() == 1:
			draw_circle(points[0], marker_radius, path_color)
			draw_string(ThemeDB.fallback_font, points[0] + Vector2(-4, -10), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		return

	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], path_color, 2.0)

	if loop and points.size() >= 2:
		draw_line(points[points.size() - 1], points[0], path_color.lightened(0.2), 1.5)

	for i in range(points.size()):
		draw_circle(points[i], marker_radius, path_color)
		draw_string(
			ThemeDB.fallback_font,
			points[i] + Vector2(-4, -10),
			str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color.WHITE
		)
