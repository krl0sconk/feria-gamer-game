# Barrera invisible activable/desactivable desde cinemáticas o por estado de quests.
@tool
class_name ScriptedBarrier
extends StaticBody2D

@export var id: String = "":
	set(value):
		id = value
		queue_redraw()

@export var active_by_default: bool = true:
	set(value):
		active_by_default = value
		if Engine.is_editor_hint():
			queue_redraw()

## Si todas estas quests están completadas al cargar, la barrera nace desactivada.
@export var disabled_by_quests: Array[String] = []:
	set(value):
		disabled_by_quests = value
		if Engine.is_editor_hint():
			queue_redraw()

## Si alguna de estas quests está activa, la barrera se desactiva (desbloquea paso).
@export var unlock_when_quests_active: Array[String] = []:
	set(value):
		unlock_when_quests_active = value
		if Engine.is_editor_hint():
			queue_redraw()

@export var editor_active_color: Color = Color(1.0, 0.2, 0.2, 0.35):
	set(value):
		editor_active_color = value
		queue_redraw()

@export var editor_inactive_color: Color = Color(0.55, 0.55, 0.55, 0.25):
	set(value):
		editor_inactive_color = value
		queue_redraw()

var _active: bool = true


func _ready() -> void:
	add_to_group("scripted_barriers")
	if Engine.is_editor_hint():
		child_entered_tree.connect(_on_editor_child_changed)
		child_exiting_tree.connect(_on_editor_child_changed)
		return

	_apply_barrier_state()

	if QuestManager.has_signal("quest_completed"):
		QuestManager.quest_completed.connect(_on_quest_completed)
	if QuestManager.has_signal("quest_activated"):
		QuestManager.quest_activated.connect(_on_quest_activated)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _on_editor_child_changed(_node: Node = null) -> void:
	queue_redraw()


func _on_quest_completed(_quest_id: String) -> void:
	_apply_barrier_state()


func _on_quest_activated(_quest_id: String) -> void:
	_apply_barrier_state()


func _apply_barrier_state() -> void:
	if _should_be_unlocked_by_active_quests() or _should_be_disabled_by_quests():
		set_active(false)
	else:
		set_active(active_by_default)


func set_active(active: bool) -> void:
	_active = active
	collision_layer = 1 if active else 0
	for child in find_children("*", "CollisionShape2D", false, false):
		(child as CollisionShape2D).disabled = not active
	for child in find_children("*", "CollisionPolygon2D", false, false):
		(child as CollisionPolygon2D).disabled = not active
	if Engine.is_editor_hint():
		queue_redraw()


func is_active() -> bool:
	return _active


static func find_by_id(barrier_id: String) -> ScriptedBarrier:
	if barrier_id.is_empty():
		return null
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	for node in tree.get_nodes_in_group("scripted_barriers"):
		if node is ScriptedBarrier and (node as ScriptedBarrier).id == barrier_id:
			return node as ScriptedBarrier
	return null


func _should_be_disabled_by_quests() -> bool:
	if disabled_by_quests.is_empty():
		return false
	for quest_id in disabled_by_quests:
		if not QuestManager.is_completed(quest_id):
			return false
	return true


func _should_be_unlocked_by_active_quests() -> bool:
	for quest_id in unlock_when_quests_active:
		var qid := str(quest_id).strip_edges()
		if qid != "" and QuestManager.is_active(qid):
			return true
	return false


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var active := active_by_default
	if not Engine.is_editor_hint() and _should_be_disabled_by_quests():
		active = false
	var fill_color := editor_active_color if active else editor_inactive_color
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		draw_circle(Vector2.ZERO, 16.0, fill_color)
		var fallback := PackedVector2Array([
			Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16),
		])
		_draw_stripes_in_polygon(fallback, active)
	else:
		_draw_collision_shape(shape_node, fill_color, active)

	var label := id if not id.is_empty() else String(name)
	draw_string(ThemeDB.fallback_font, Vector2(-40, -24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _draw_collision_shape(shape_node: CollisionShape2D, fill_color: Color, active: bool) -> void:
	var local_xform := shape_node.transform
	var shape := shape_node.shape

	if shape is RectangleShape2D:
		var rect_shape := shape as RectangleShape2D
		var half := rect_shape.size * 0.5
		var corners: PackedVector2Array = PackedVector2Array([
			local_xform * Vector2(-half.x, -half.y),
			local_xform * Vector2(half.x, -half.y),
			local_xform * Vector2(half.x, half.y),
			local_xform * Vector2(-half.x, half.y),
		])
		draw_colored_polygon(corners, fill_color)
		for i in range(corners.size()):
			draw_line(corners[i], corners[(i + 1) % corners.size()], fill_color.lightened(0.35), 2.0)
		_draw_stripes_in_polygon(corners, active)
	elif shape is CircleShape2D:
		var circle := shape as CircleShape2D
		var center: Vector2 = local_xform.origin
		draw_circle(center, circle.radius, fill_color)
		draw_arc(center, circle.radius, 0.0, TAU, 32, fill_color.lightened(0.35), 2.0)
	else:
		draw_circle(local_xform.origin, 16.0, fill_color)


func _draw_stripes_in_polygon(corners: PackedVector2Array, active: bool) -> void:
	if corners.size() < 3:
		return
	var bounds := _corners_bounds(corners)
	var stripe_color := Color(1.0, 0.2, 0.2, 0.45) if active else Color(0.5, 0.5, 0.5, 0.4)
	var spacing := 14.0
	var y := bounds.position.y
	while y <= bounds.position.y + bounds.size.y:
		var line := PackedVector2Array([
			Vector2(bounds.position.x - 4.0, y),
			Vector2(bounds.position.x + bounds.size.x + 4.0, y),
		])
		var clipped: Array = Geometry2D.intersect_polyline_with_polygon(line, corners)
		for segment in clipped:
			if segment is PackedVector2Array and (segment as PackedVector2Array).size() >= 2:
				var pts := segment as PackedVector2Array
				draw_line(pts[0], pts[pts.size() - 1], stripe_color, 1.5)
		y += spacing


func _corners_bounds(corners: PackedVector2Array) -> Rect2:
	if corners.is_empty():
		return Rect2(-16, -16, 32, 32)
	var min_v := corners[0]
	var max_v := corners[0]
	for corner in corners:
		min_v.x = minf(min_v.x, corner.x)
		min_v.y = minf(min_v.y, corner.y)
		max_v.x = maxf(max_v.x, corner.x)
		max_v.y = maxf(max_v.y, corner.y)
	return Rect2(min_v, max_v - min_v)
