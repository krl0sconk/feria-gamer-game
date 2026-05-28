@tool
extends EditorPlugin

const SCENE_TRIGGER := "res://scenes/cinematic/ScriptedTrigger.tscn"
const SCENE_BARRIER := "res://scenes/cinematic/ScriptedBarrier.tscn"
const SCENE_WAYPOINT_PATH := "res://scenes/cinematic/WaypointPath.tscn"
const SCENE_INDICATOR := "res://scenes/cinematic/InteractionIndicator.tscn"

var _toolbar: HBoxContainer


func _enter_tree() -> void:
	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 6)

	_add_scene_button("+ Trigger", "Instanciar ScriptedTrigger", SCENE_TRIGGER)
	_add_scene_button("+ Barrier", "Instanciar ScriptedBarrier", SCENE_BARRIER)
	_add_scene_button("+ Path", "Instanciar WaypointPath", SCENE_WAYPOINT_PATH)
	_add_action_button("+ Waypoint", "Añadir waypoint al WaypointPath seleccionado", _on_add_waypoint_pressed)
	_add_scene_button("+ !", "Instanciar InteractionIndicator (hijo del seleccionado o en canvas)", SCENE_INDICATOR, true)

	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)


func _exit_tree() -> void:
	if _toolbar != null:
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
		_toolbar.queue_free()
		_toolbar = null


func _add_scene_button(label: String, tooltip: String, scene_path: String, prefer_selection_parent: bool = false) -> void:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.pressed.connect(func() -> void:
		_instance_packed_scene(scene_path, prefer_selection_parent)
	)
	_toolbar.add_child(button)


func _add_action_button(label: String, tooltip: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	_toolbar.add_child(button)


func _instance_packed_scene(scene_path: String, prefer_selection_parent: bool) -> void:
	var edited_root := get_editor_interface().get_edited_scene_root()
	if edited_root == null:
		push_warning("Cinematic Authoring: abre una escena de mapa primero.")
		return

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Cinematic Authoring: no se pudo cargar %s" % scene_path)
		return

	var instance: Node = packed.instantiate()
	var parent := _resolve_parent(prefer_selection_parent)
	var spawn_pos := _get_canvas_spawn_position()

	if instance is Node2D:
		if parent is Node2D:
			(instance as Node2D).position = (parent as Node2D).to_local(spawn_pos)
		else:
			(instance as Node2D).position = spawn_pos

	_commit_add_node(instance, parent, edited_root)
	_select_node(instance)


func _on_add_waypoint_pressed() -> void:
	var edited_root := get_editor_interface().get_edited_scene_root()
	if edited_root == null:
		push_warning("Cinematic Authoring: abre una escena de mapa primero.")
		return

	var path_node := _find_selected_waypoint_path()
	if path_node == null:
		push_warning("Cinematic Authoring: selecciona un nodo WaypointPath.")
		return

	if not path_node.has_method("add_waypoint_from_editor"):
		push_warning("Cinematic Authoring: WaypointPath sin add_waypoint_from_editor().")
		return

	var before_count: int = path_node.get_waypoint_count() if path_node.has_method("get_waypoint_count") else 0
	path_node.call("add_waypoint_from_editor")
	var after_count: int = path_node.get_waypoint_count() if path_node.has_method("get_waypoint_count") else before_count + 1

	if after_count <= before_count:
		return

	var marker: Node = path_node.get_child(path_node.get_child_count() - 1)
	_select_node(marker)
	get_editor_interface().mark_scene_as_unsaved()


func _resolve_parent(prefer_selection: bool) -> Node:
	var edited_root := get_editor_interface().get_edited_scene_root()
	if not prefer_selection:
		return edited_root

	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if selected.is_empty():
		return edited_root
	return selected[0]


func _find_selected_waypoint_path() -> Node:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	for node in selected:
		if _is_waypoint_path(node):
			return node
		if node.get_script() != null:
			var script_path: String = node.get_script().resource_path
			if script_path.ends_with("waypoint_path.gd"):
				return node
	return null


func _is_waypoint_path(node: Node) -> bool:
	if node == null:
		return false
	if node.has_method("get_waypoints") and node.has_method("get_waypoint_count"):
		return true
	return false


func _get_canvas_spawn_position() -> Vector2:
	var viewport_2d := get_editor_interface().get_editor_viewport_2d()
	if viewport_2d == null:
		return Vector2.ZERO
	var canvas_transform: Transform2D = viewport_2d.global_canvas_transform
	return canvas_transform.affine_inverse() * viewport_2d.get_mouse_position()


func _commit_add_node(instance: Node, parent: Node, edited_root: Node) -> void:
	var undo := get_undo_redo()
	var action_name := "Añadir %s" % instance.name
	undo.create_action(action_name)
	undo.add_do_method(parent, "add_child", instance)
	undo.add_do_method(instance, "set_owner", edited_root)
	undo.add_undo_method(parent, "remove_child", instance)
	undo.add_do_reference(instance)
	undo.commit_action()
	get_editor_interface().mark_scene_as_unsaved()


func _select_node(node: Node) -> void:
	var selection := get_editor_interface().get_selection()
	selection.clear()
	selection.add_node(node)
