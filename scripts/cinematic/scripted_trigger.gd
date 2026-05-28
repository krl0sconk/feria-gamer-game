# Disparador de cinemática independiente. Colócalo en el mapa y ajusta el Area2D
# en el editor — no hace falta escribir coordenadas en JSON.
@tool
class_name ScriptedTrigger
extends Area2D

@export_file("*.json") var cinematic_json_path: String = "":
	set(value):
		cinematic_json_path = value
		queue_redraw()

## Solo dispara si esta quest está completada (vacío = sin requisito).
@export var requires_quest: String = ""

## No dispara si esta quest ya está completada (vacío = sin bloqueo).
@export var blocked_if_quest_completed: String = ""

## Si true, consulta Gamemanager.cinematics_played con el id del JSON.
@export var play_once: bool = true

@export var debug_label: String = ""

@export var show_indicator: bool = true

@export var editor_fill_color: Color = Color(1.0, 0.85, 0.1, 0.25):
	set(value):
		editor_fill_color = value
		queue_redraw()

var _armed: bool = true
## Anti-rebote por carga de escena: si el jugador aparece encima del trigger,
## queremos ignorar el primer body_entered automático.
var _trigger_unlock_msec: int = 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if Engine.is_editor_hint():
		child_entered_tree.connect(_on_editor_child_changed)
		child_exiting_tree.connect(_on_editor_child_changed)
		return

	monitoring = true
	monitorable = false
	collision_layer = 0
	if collision_mask == 0:
		collision_mask = 1
	_trigger_unlock_msec = Time.get_ticks_msec() + 600
	_setup_indicator()


func should_show_indicator() -> bool:
	if not show_indicator:
		return false
	if cinematic_json_path.is_empty():
		return false
	if not _passes_quest_filters():
		return false
	if play_once and _is_cinematic_already_played():
		return false
	if not _armed:
		return false
	return true


func _setup_indicator() -> void:
	var indicator := get_node_or_null("InteractionIndicator")
	if not show_indicator:
		if indicator != null:
			indicator.visible = false
		return
	if indicator == null:
		var packed: PackedScene = load("res://scenes/cinematic/InteractionIndicator.tscn")
		if packed == null:
			push_warning("ScriptedTrigger '%s': no se pudo cargar InteractionIndicator.tscn." % name)
			return
		indicator = packed.instantiate()
		indicator.name = "InteractionIndicator"
		add_child(indicator)
	if indicator.has_method("refresh"):
		indicator.call("refresh")


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _on_editor_child_changed(_node: Node = null) -> void:
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if Engine.is_editor_hint() or not _armed:
		return
	if not body.is_in_group("player"):
		return
	if Time.get_ticks_msec() < _trigger_unlock_msec:
		return
	if not _passes_quest_filters():
		return
	if cinematic_json_path.is_empty():
		push_warning("ScriptedTrigger '%s': cinematic_json_path vacío." % name)
		return
	if play_once and _is_cinematic_already_played():
		return

	_armed = false if play_once else true
	Gamemanager.request_cinematic(cinematic_json_path, {"play_once": play_once})
	_refresh_indicator()


func _refresh_indicator() -> void:
	var indicator := get_node_or_null("InteractionIndicator")
	if indicator != null and indicator.has_method("refresh"):
		indicator.call("refresh")


func _passes_quest_filters() -> bool:
	if not requires_quest.is_empty() and not QuestManager.is_completed(requires_quest):
		return false
	if not blocked_if_quest_completed.is_empty() and QuestManager.is_completed(blocked_if_quest_completed):
		return false
	return true


func _is_cinematic_already_played() -> bool:
	var data := CinematicLoader.load_json(cinematic_json_path)
	if data.id.is_empty():
		return false
	return bool(Gamemanager.cinematics_played.get(data.id, false))


func rearm() -> void:
	_armed = true
	_refresh_indicator()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		draw_circle(Vector2.ZERO, 16.0, editor_fill_color)
	else:
		_draw_collision_shape(shape_node)

	var label: String = debug_label if not debug_label.is_empty() else String(name)
	if not cinematic_json_path.is_empty():
		label += "\n" + cinematic_json_path.get_file()
	draw_string(ThemeDB.fallback_font, Vector2(-40, -24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _draw_collision_shape(shape_node: CollisionShape2D) -> void:
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
		draw_colored_polygon(corners, editor_fill_color)
		for i in range(corners.size()):
			draw_line(corners[i], corners[(i + 1) % corners.size()], path_color_outline(), 2.0)
	elif shape is CircleShape2D:
		var circle := shape as CircleShape2D
		var center: Vector2 = local_xform.origin
		draw_circle(center, circle.radius, editor_fill_color)
		draw_arc(center, circle.radius, 0.0, TAU, 32, path_color_outline(), 2.0)
	else:
		draw_circle(local_xform.origin, 16.0, editor_fill_color)


func path_color_outline() -> Color:
	return editor_fill_color.lightened(0.35)
