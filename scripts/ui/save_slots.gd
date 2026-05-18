extends Control

const SLOTS := 3
@export var show_delete_buttons: bool = false

@onready var btns := [ $VBox/Slot1/BtnSlot1, $VBox/Slot2/BtnSlot2, $VBox/Slot3/BtnSlot3 ]
@onready var dels := [ $VBox/Slot1/BtnDel1, $VBox/Slot2/BtnDel2, $VBox/Slot3/BtnDel3 ]
@onready var _back := $Back
@onready var infos := [ $VBox/Slot1/BtnSlot1/Info, $VBox/Slot2/BtnSlot2/Info, $VBox/Slot3/BtnSlot3/Info ]

func _ready() -> void:
	btns[0].pressed.connect(_on_slot1_pressed)
	btns[1].pressed.connect(_on_slot2_pressed)
	btns[2].pressed.connect(_on_slot3_pressed)
	dels[0].pressed.connect(_on_delete1_pressed)
	dels[1].pressed.connect(_on_delete2_pressed)
	dels[2].pressed.connect(_on_delete3_pressed)
	_back.pressed.connect(_on_back_pressed)

	print("save_slots: connected slot/delete/back signals")

	# Debug checks: report missing nodes early to help runtime tracing
	for i in range(SLOTS):
		if btns[i] == null:
			push_error("save_slots: btns[%d] es null" % i)
		if dels[i] == null:
			push_error("save_slots: dels[%d] es null" % i)
		if infos[i] == null:
			push_error("save_slots: infos[%d] es null" % i)
	print("save_slots: _ready completed")

	_refresh()

	# Aplicar visibilidad inicial de botones Delete
	for i in range(SLOTS):
		if dels[i] != null:
			dels[i].visible = show_delete_buttons
		else:
			push_error("save_slots: dels[%d] nulo al aplicar visibilidad inicial" % i)

	print("save_slots: delete buttons visible = %s" % str(show_delete_buttons))


func _input(event) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Obtener el código de tecla de forma compatible con Godot 3/4
		var code := -1
		var sc = event.get("scancode")
		if sc != null:
			code = int(sc)
		else:
			var kc = event.get("keycode")
			if kc != null:
				code = int(kc)
		if code >= 0:
			# Preferir unicode cuando esté disponible (tecla alfanumérica)
			var uni = event.get("unicode")
			if uni != null:
				var uval := int(uni)
				if uval == ord("d") or uval == ord("D"):
					show_delete_buttons = not show_delete_buttons
					for i in range(SLOTS):
						if dels[i] != null:
							dels[i].visible = show_delete_buttons
					print("save_slots: toggle delete buttons -> %s" % str(show_delete_buttons))


func _refresh() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	var list := []
	if sm != null and sm.has_method("list_slots"):
		list = sm.list_slots()
	for i in range(SLOTS):
		var info: Dictionary = {}
		if i < list.size():
			var maybe = list[i]
			if typeof(maybe) == TYPE_DICTIONARY:
				info = maybe
		var exists: bool = bool(info.get("exists", false))
		btns[i].text = "Slot %d" % (i + 1)
		if exists:
			var meta: Dictionary = {}
			if info.has("metadata") and typeof(info.get("metadata")) == TYPE_DICTIONARY:
				meta = info.get("metadata") as Dictionary
			var ts := int(meta.get("updated_at", 0))
			var ts_text := ""
			if ts > 0:
				ts_text = str(ts)
			infos[i].text = "Guardado\n%s" % ts_text
		else:
			infos[i].text = "Vacío"

func _on_slot_pressed(slot_idx: int) -> void:
	print("save_slots: _on_slot_pressed invoked for slot %d" % slot_idx)
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		return
	if sm.has_method("set_active_slot"):
		sm.set_active_slot(slot_idx)
	var payload: Dictionary = {}
	if sm.has_method("load_slot"):
		payload = sm.load_slot(slot_idx) as Dictionary
	print("save_slots: payload size = %d" % payload.size())

	if payload.size() == 0:
		print("save_slots: payload vacío, lanzando select_pj.tscn sin crear save todavía")
		# Asegurar SceneTree y cambiar a selector de personaje
		var _tree = get_tree()
		if _tree == null:
			var ml = Engine.get_main_loop()
			if ml != null and ml is SceneTree:
				_tree = ml as SceneTree
		if _tree == null:
			push_error("save_slots: no SceneTree disponible para cambiar a select_pj")
			return
		_tree.call_deferred("change_scene_to_file", "res://scenes/menu/select_pj.tscn")
		return
	var pdict: Dictionary = payload.get("player", {}) as Dictionary
	var scene_path: String = str(pdict.get("scene_path", ""))
	print("save_slots: scene_path='%s'" % scene_path)
	if scene_path.ends_with("save_slots.tscn") or scene_path.ends_with("select_pj.tscn"):
		print("save_slots: escena guardada apunta a menú/selector; tratando como partida nueva")
		var _tree_bad := get_tree()
		if _tree_bad == null:
			var ml_bad = Engine.get_main_loop()
			if ml_bad != null and ml_bad is SceneTree:
				_tree_bad = ml_bad as SceneTree
		if _tree_bad == null:
			push_error("save_slots: no SceneTree disponible para cambiar a select_pj")
			return
		_tree_bad.call_deferred("change_scene_to_file", "res://scenes/menu/select_pj.tscn")
		return
	# Verificar que la escena existe como recurso
	var exists_scene := true
	if scene_path != "":
		if not ResourceLoader.exists(scene_path):
			exists_scene = false
			push_error("save_slots: escena guardada no encontrada: %s" % scene_path)
		else:
			print("save_slots: escena encontrada: %s" % scene_path)
	if scene_path == "":
		print("save_slots: scene_path vacío, lanzando select_pj.tscn")
		var _tree2 = get_tree()
		if _tree2 == null:
			var ml2 = Engine.get_main_loop()
			if ml2 != null and ml2 is SceneTree:
				_tree2 = ml2 as SceneTree
		if _tree2 == null:
			push_error("save_slots: no SceneTree disponible para cambiar a select_pj (scene_path vacío)")
			return
		_tree2.call_deferred("change_scene_to_file", "res://scenes/menu/select_pj.tscn")
		return

	# Aplicar skin en Gamemanager si está presente
	var gm := get_node_or_null("/root/Gamemanager")
	if gm != null and pdict.has("selected_skin"):
		gm.selectedskin = str(pdict.get("selected_skin", ""))
	if gm != null:
		var pos_dict: Dictionary = pdict.get("position", {"x": 0.0, "y": 0.0}) as Dictionary
		var nx := float(pos_dict.get("x", 0.0))
		var ny := float(pos_dict.get("y", 0.0))
		if gm.has_method("set_loaded_position"):
			gm.set_loaded_position(Vector2(nx, ny))

	# Cambiar a la escena guardada y esperar unos frames a que cargue
	print("save_slots: cargando escena guardada: %s" % scene_path)
	var _tree3 = get_tree()
	print("save_slots: get_tree() -> %s" % str(_tree3))
	if _tree3 == null:
		print("save_slots: get_tree() es null, usando Engine.get_main_loop()")
		_tree3 = Engine.get_main_loop()
	print("save_slots: using tree -> %s" % str(_tree3))
	if _tree3 == null:
		push_error("save_slots: no SceneTree disponible para cambiar a escena guardada: %s" % scene_path)
		return
	if exists_scene:
		_tree3.call_deferred("change_scene_to_file", scene_path)
		print("save_slots: scheduled change to %s" % scene_path)
	else:
		push_error("save_slots: no se programó cambio de escena porque no existe: %s" % scene_path)
	await _tree3.process_frame
	await _tree3.process_frame

	# Restaurar estado de misiones si el QuestManager soporta apply_state
	var qm2 := get_node_or_null("/root/QuestManager")
	if qm2 != null and qm2.has_method("apply_state"):
		qm2.apply_state(payload.get("quests", []))

func _on_delete_pressed(slot_idx: int) -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		return
	if sm.has_method("get_active_slot") and sm.get_active_slot() == slot_idx:
		sm.set_active_slot(0)
	sm.delete_slot(slot_idx)
	_refresh()

func _on_back_pressed() -> void:
	print("save_slots: back pressed")
	# Si el nodo no está en el árbol todavía, deferir el cambio de escena
	if not is_inside_tree():
		push_error("save_slots: not inside tree en back_pressed; defiriendo cambio de escena")
		call_deferred("_deferred_change_to_main_menu")
		return
	# Usar call_deferred para evitar problemas de estado interno del SceneTree
	var _t = get_tree()
	if _t == null:
		var ml = Engine.get_main_loop()
		if ml != null and ml is SceneTree:
			_t = ml as SceneTree
		else:
			push_error("save_slots: get_tree() y Engine.get_main_loop() son null en _on_back_pressed()")
			return
	print("save_slots: scheduling scene change to main_menu.tscn")
	_t.call_deferred("change_scene_to_file", "res://scenes/menu/main_menu.tscn")


func _deferred_change_to_main_menu() -> void:
	var _t = get_tree()
	if _t == null:
		var ml = Engine.get_main_loop()
		if ml != null and ml is SceneTree:
			_t = ml as SceneTree
		else:
			push_error("save_slots: no se pudo obtener SceneTree en deferred change")
			return
	print("save_slots: deferred changing to main_menu.tscn")
	_t.call_deferred("change_scene_to_file", "res://scenes/menu/main_menu.tscn")


func _open_slot(slot_idx: int) -> void:
	_on_slot_pressed(slot_idx)


func _delete_slot(slot_idx: int) -> void:
	_on_delete_pressed(slot_idx)


func _back_to_menu() -> void:
	_on_back_pressed()


func _on_slot1_pressed() -> void:
	_on_slot_pressed(1)


func _on_slot2_pressed() -> void:
	_on_slot_pressed(2)


func _on_slot3_pressed() -> void:
	_on_slot_pressed(3)


func _on_delete1_pressed() -> void:
	_on_delete_pressed(1)


func _on_delete2_pressed() -> void:
	_on_delete_pressed(2)


func _on_delete3_pressed() -> void:
	_on_delete_pressed(3)
