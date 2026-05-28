# Editor visual de cinemáticas. Crea, edita y exporta archivos JSON compatibles
# con CinematicPlayer. Instancia scenes/editor/cinematic_editor.tscn para usarlo.
#
# Layout: TopBar | HSplitContainer (Panel izquierdo: trigger + lista de pasos;
#                                    Panel derecho: formulario del paso + preview JSON)
class_name CinematicEditor
extends Control

const DEFAULT_DIR: String = "res://assets/cinematics"

const STEP_TYPES: Array[String] = [
	"fade_to_black", "fade_from_black", "wait", "dialogue",
	"move_node", "show_node", "hide_node", "disable_player", "enable_player",
	"change_scene",
]

const STEP_LABEL: Dictionary = {
	"fade_to_black":   "Fundido a negro",
	"fade_from_black": "Fundido desde negro",
	"wait":            "Esperar",
	"dialogue":        "Dialogo",
	"move_node":       "Mover nodo",
	"show_node":       "Mostrar nodo",
	"hide_node":       "Ocultar nodo",
	"disable_player":  "Bloquear jugador",
	"enable_player":   "Liberar jugador",
	"change_scene":    "Cambiar escena",
}

var _data: CinematicLoader.CinematicData = null
var _sel: int = -1
var _path: String = ""
var _syncing: bool = false
## LineEdit del paso actual que recibirá la ruta del FileDialog de assets.
var _asset_target_edit: LineEdit = null

# Refs a nodos de UI (construidos en _build_ui)
var _id_edit: LineEdit
var _trigger_type_opt: OptionButton
var _trigger_extra_label: Label
var _trigger_extra_edit: LineEdit
var _step_list: ItemList
var _step_type_opt: OptionButton
var _detail_panel: VBoxContainer
var _json_preview: TextEdit
var _status_label: Label
var _file_dialog_load: FileDialog
var _file_dialog_save: FileDialog
var _file_dialog_asset: FileDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_new_cinematic()


# ── Construcción de UI ────────────────────────────────────────────────────────

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   8)
	margin.add_theme_constant_override("margin_right",  8)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(root_vbox)

	_build_top_bar(root_vbox)
	root_vbox.add_child(_make_hsep())

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 390
	root_vbox.add_child(split)

	_build_left_panel(split)
	_build_right_panel(split)
	_build_file_dialogs()


func _build_top_bar(parent: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)

	var new_btn := _make_button("Nuevo", _on_new_pressed)
	var load_btn := _make_button("Cargar", func(): _file_dialog_load.popup_centered_ratio(0.7))
	var save_btn := _make_button("Guardar", _on_save_pressed)
	var save_as_btn := _make_button("Guardar como...", func(): _file_dialog_save.popup_centered_ratio(0.7))
	_set_shortcut(save_btn, KEY_S, true)

	hbox.add_child(new_btn)
	hbox.add_child(load_btn)
	hbox.add_child(save_btn)
	hbox.add_child(save_as_btn)
	hbox.add_child(_make_vsep())

	hbox.add_child(_make_label("  ID:"))
	_id_edit = LineEdit.new()
	_id_edit.custom_minimum_size.x = 200
	_id_edit.placeholder_text = "id_cinematica"
	_id_edit.text_changed.connect(_on_id_changed)
	hbox.add_child(_id_edit)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(_status_label)


func _build_left_panel(split: HSplitContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 340
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	# ── Sección Trigger ───────────────────────────────────────────────────────
	vbox.add_child(_make_section_label("TRIGGER"))

	var trig_grid := GridContainer.new()
	trig_grid.columns = 2
	trig_grid.add_theme_constant_override("h_separation", 8)
	trig_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(trig_grid)

	trig_grid.add_child(_make_label("Tipo:"))
	_trigger_type_opt = OptionButton.new()
	_trigger_type_opt.add_item("Al cargar escena (on_scene_ready)")
	_trigger_type_opt.add_item("Al completar quest (on_quest_completed)")
	_trigger_type_opt.add_item("Al pisar area (on_area_entered)")
	_trigger_type_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trigger_type_opt.item_selected.connect(_on_trigger_type_selected)
	trig_grid.add_child(_trigger_type_opt)

	_trigger_extra_label = _make_label("Delay (s):")
	trig_grid.add_child(_trigger_extra_label)

	_trigger_extra_edit = LineEdit.new()
	_trigger_extra_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trigger_extra_edit.text_changed.connect(_on_trigger_param_changed)
	trig_grid.add_child(_trigger_extra_edit)

	var area_hint := Label.new()
	area_hint.text = "Para on_area_entered: agrega un hijo Area2D\nllamado 'TriggerArea' al nodo CinematicPlayer."
	area_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	area_hint.name = "_area_hint"
	area_hint.visible = false
	vbox.add_child(area_hint)

	vbox.add_child(_make_hsep())

	# ── Sección Pasos ─────────────────────────────────────────────────────────
	vbox.add_child(_make_section_label("PASOS"))

	_step_list = ItemList.new()
	_step_list.custom_minimum_size.y = 300
	_step_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_step_list.item_selected.connect(_on_step_selected)
	_step_list.empty_clicked.connect(func(_p, _b): _sel = -1; _refresh_detail(); _refresh_json())
	vbox.add_child(_step_list)

	var add_row := HBoxContainer.new()
	vbox.add_child(add_row)
	_step_type_opt = OptionButton.new()
	_step_type_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for st in STEP_TYPES:
		_step_type_opt.add_item(STEP_LABEL.get(st, st))
	add_row.add_child(_step_type_opt)
	add_row.add_child(_make_button("Agregar", _on_add_step))

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 4)
	vbox.add_child(action_row)
	action_row.add_child(_make_button("Duplicar", _on_duplicate_step))
	action_row.add_child(_make_button("Eliminar", _on_delete_step))
	action_row.add_child(_make_vsep())
	action_row.add_child(_make_button("Subir",  _on_move_up))
	action_row.add_child(_make_button("Bajar",  _on_move_down))


func _build_right_panel(split: HSplitContainer) -> void:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	split.add_child(vbox)

	vbox.add_child(_make_section_label("DETALLE DEL PASO"))

	_detail_panel = VBoxContainer.new()
	_detail_panel.custom_minimum_size.y = 180
	_detail_panel.add_theme_constant_override("separation", 6)
	vbox.add_child(_detail_panel)

	vbox.add_child(_make_hsep())

	var preview_hdr := HBoxContainer.new()
	vbox.add_child(preview_hdr)
	preview_hdr.add_child(_make_section_label("PREVIEW JSON"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_hdr.add_child(spacer)
	preview_hdr.add_child(_make_button("Validar", _on_validate_pressed))

	_json_preview = TextEdit.new()
	_json_preview.editable = false
	_json_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_json_preview.custom_minimum_size.y = 180
	vbox.add_child(_json_preview)


func _build_file_dialogs() -> void:
	_file_dialog_load = _make_file_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	_file_dialog_load.file_selected.connect(_on_load_file_selected)
	add_child(_file_dialog_load)

	_file_dialog_save = _make_file_dialog(FileDialog.FILE_MODE_SAVE_FILE)
	_file_dialog_save.filters = ["*.json ; Cinematic JSON"]
	_file_dialog_save.file_selected.connect(_on_save_file_selected)
	add_child(_file_dialog_save)

	_file_dialog_asset = _make_file_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	_file_dialog_asset.file_selected.connect(_on_asset_file_selected)
	add_child(_file_dialog_asset)


func _make_file_dialog(mode: FileDialog.FileMode) -> FileDialog:
	var dlg := FileDialog.new()
	dlg.file_mode = mode
	dlg.access = FileDialog.ACCESS_RESOURCES
	dlg.filters = ["*.json ; JSON"]
	dlg.current_dir = DEFAULT_DIR
	return dlg


# ── Helpers de construcción ───────────────────────────────────────────────────

func _make_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	return btn


func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	return lbl


func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	return lbl


func _make_hsep() -> HSeparator:
	return HSeparator.new()


func _make_vsep() -> VSeparator:
	return VSeparator.new()


func _set_shortcut(btn: Button, key: Key, ctrl: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.ctrl_pressed = ctrl
	var sc := Shortcut.new()
	sc.events = [ev]
	btn.shortcut = sc


# ── Cinemática nueva ──────────────────────────────────────────────────────────

func _new_cinematic() -> void:
	_data = CinematicLoader.CinematicData.new()
	_data.id      = "nueva_cinematica"
	_data.trigger = {"type": "on_scene_ready", "delay": 0.0}
	_data.steps   = []
	_sel  = -1
	_path = ""
	_refresh_all()
	_set_status("Nuevo archivo sin guardar.")


# ── Nuevo / Cargar / Guardar ──────────────────────────────────────────────────

func _on_new_pressed() -> void:
	_new_cinematic()


func _on_save_pressed() -> void:
	if _path.is_empty():
		_file_dialog_save.popup_centered_ratio(0.7)
	else:
		_do_save(_path)


func _on_load_file_selected(file_path: String) -> void:
	_data = CinematicLoader.load_json(file_path)
	_path = file_path
	_sel  = -1
	_refresh_all()
	_set_status("Cargado: %s" % file_path.get_file())


func _on_save_file_selected(file_path: String) -> void:
	_path = file_path
	_do_save(file_path)


func _do_save(file_path: String) -> void:
	_data.id = _id_edit.text.strip_edges()
	var err := CinematicLoader.save_json(file_path, _data)
	if err == OK:
		_set_status("Guardado: %s" % file_path.get_file())
	else:
		_set_status("Error al guardar (codigo %d)" % err)


func _on_asset_file_selected(file_path: String) -> void:
	if _asset_target_edit != null and is_instance_valid(_asset_target_edit):
		_asset_target_edit.text = file_path
	_asset_target_edit = null


# ── Pasos: agregar / eliminar / duplicar / ordenar ───────────────────────────

func _on_add_step() -> void:
	var type_idx: int = _step_type_opt.selected
	if type_idx < 0 or type_idx >= STEP_TYPES.size():
		return
	var step := CinematicLoader.CinematicStep.new()
	step.type   = STEP_TYPES[type_idx]
	step.params = _default_params(step.type)
	var insert_at: int = (_sel + 1) if _sel >= 0 else _data.steps.size()
	_data.steps.insert(insert_at, step)
	_sel = insert_at
	_refresh_step_list()
	_step_list.select(_sel)
	_refresh_detail()
	_refresh_json()


func _default_params(step_type: String) -> Dictionary:
	match step_type:
		"fade_to_black", "fade_from_black":  return {"duration": 0.5}
		"wait":                               return {"seconds": 1.0}
		"dialogue":                           return {"path": DEFAULT_DIR + "/", "id": ""}
		"move_node":                          return {"node": "", "to": [0.0, 0.0], "duration": 1.0}
		"show_node", "hide_node":             return {"node": ""}
		"change_scene":                       return {"path": "res://scenes/map/"}
	return {}


func _on_delete_step() -> void:
	if _sel < 0 or _sel >= _data.steps.size():
		return
	_data.steps.remove_at(_sel)
	_sel = mini(_sel, _data.steps.size() - 1)
	_refresh_step_list()
	if _sel >= 0:
		_step_list.select(_sel)
	_refresh_detail()
	_refresh_json()


func _on_duplicate_step() -> void:
	if _sel < 0 or _sel >= _data.steps.size():
		return
	var src: CinematicLoader.CinematicStep = _data.steps[_sel]
	var copy := CinematicLoader.CinematicStep.new()
	copy.type   = src.type
	copy.params = src.params.duplicate(true)
	_data.steps.insert(_sel + 1, copy)
	_sel += 1
	_refresh_step_list()
	_step_list.select(_sel)
	_refresh_detail()
	_refresh_json()


func _on_move_up() -> void:
	if _sel <= 0:
		return
	var tmp: CinematicLoader.CinematicStep = _data.steps[_sel - 1]
	_data.steps[_sel - 1] = _data.steps[_sel]
	_data.steps[_sel]     = tmp
	_sel -= 1
	_refresh_step_list()
	_step_list.select(_sel)
	_refresh_json()


func _on_move_down() -> void:
	if _sel < 0 or _sel >= _data.steps.size() - 1:
		return
	var tmp: CinematicLoader.CinematicStep = _data.steps[_sel + 1]
	_data.steps[_sel + 1] = _data.steps[_sel]
	_data.steps[_sel]     = tmp
	_sel += 1
	_refresh_step_list()
	_step_list.select(_sel)
	_refresh_json()


func _on_step_selected(index: int) -> void:
	_sel = index
	_refresh_detail()


# ── Trigger ───────────────────────────────────────────────────────────────────

func _on_id_changed(text: String) -> void:
	if _syncing:
		return
	_data.id = text.strip_edges()
	_refresh_json()


func _on_trigger_type_selected(index: int) -> void:
	if _syncing:
		return
	var area_hint: Node = get_node_or_null("%/_area_hint")
	# Find the hint label we added to left vbox
	var hint: Label = _find_area_hint()
	match index:
		0:
			_data.trigger = {"type": "on_scene_ready", "delay": 0.0}
			_trigger_extra_label.text   = "Delay (s):"
			_trigger_extra_edit.text    = "0.0"
			_trigger_extra_label.visible = true
			_trigger_extra_edit.visible  = true
			if hint: hint.visible = false
		1:
			_data.trigger = {"type": "on_quest_completed", "quest_id": ""}
			_trigger_extra_label.text   = "Quest ID:"
			_trigger_extra_edit.text    = ""
			_trigger_extra_label.visible = true
			_trigger_extra_edit.visible  = true
			if hint: hint.visible = false
		2:
			_data.trigger = {"type": "on_area_entered"}
			_trigger_extra_label.visible = false
			_trigger_extra_edit.visible  = false
			if hint: hint.visible = true
	_refresh_json()


func _find_area_hint() -> Label:
	return _find_child_by_name(self, "_area_hint") as Label


func _find_child_by_name(node: Node, target: String) -> Node:
	if node.name == target:
		return node
	for child in node.get_children():
		var result := _find_child_by_name(child, target)
		if result:
			return result
	return null


func _on_trigger_param_changed(value: String) -> void:
	if _syncing:
		return
	match _trigger_type_opt.selected:
		0:
			_data.trigger["delay"] = float(value) if value.is_valid_float() else 0.0
		1:
			_data.trigger["quest_id"] = value
	_refresh_json()


# ── Validación ────────────────────────────────────────────────────────────────

func _on_validate_pressed() -> void:
	var issues := _validate()
	if issues.is_empty():
		_set_status("OK: sin errores")
	else:
		_set_status("Problemas: " + " | ".join(issues))


func _validate() -> Array[String]:
	var issues: Array[String] = []
	if _data.id.strip_edges().is_empty():
		issues.append("ID vacio")
	for i in range(_data.steps.size()):
		var step: CinematicLoader.CinematicStep = _data.steps[i]
		if step.type == "dialogue":
			if str(step.params.get("path", "")).is_empty():
				issues.append("Paso %d (dialogo): path vacio" % (i + 1))
			if str(step.params.get("id", "")).is_empty():
				issues.append("Paso %d (dialogo): id vacio" % (i + 1))
		if step.type in ["move_node", "show_node", "hide_node"]:
			if str(step.params.get("node", "")).is_empty():
				issues.append("Paso %d (%s): node vacio" % [i + 1, step.type])
	return issues


# ── Refresh de UI ─────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	_syncing = true
	_id_edit.text = _data.id
	_refresh_trigger_ui()
	_refresh_step_list()
	_syncing = false
	_refresh_detail()
	_refresh_json()


func _refresh_trigger_ui() -> void:
	var ttype: String = str(_data.trigger.get("type", "on_scene_ready"))
	var hint: Label   = _find_area_hint()
	match ttype:
		"on_scene_ready":
			_trigger_type_opt.select(0)
			_trigger_extra_label.text    = "Delay (s):"
			_trigger_extra_edit.text     = str(_data.trigger.get("delay", 0.0))
			_trigger_extra_label.visible = true
			_trigger_extra_edit.visible  = true
			if hint: hint.visible = false
		"on_quest_completed":
			_trigger_type_opt.select(1)
			_trigger_extra_label.text    = "Quest ID:"
			_trigger_extra_edit.text     = str(_data.trigger.get("quest_id", ""))
			_trigger_extra_label.visible = true
			_trigger_extra_edit.visible  = true
			if hint: hint.visible = false
		"on_area_entered":
			_trigger_type_opt.select(2)
			_trigger_extra_label.visible = false
			_trigger_extra_edit.visible  = false
			if hint: hint.visible = true


func _refresh_step_list() -> void:
	var scroll_v: float = _step_list.get_v_scroll_bar().value if _step_list.item_count > 0 else 0.0
	_step_list.clear()
	for i in range(_data.steps.size()):
		_step_list.add_item("%d. %s" % [i + 1, _step_desc(_data.steps[i])])
	if _sel >= 0 and _sel < _step_list.item_count:
		_step_list.select(_sel)
	_step_list.get_v_scroll_bar().value = scroll_v


func _step_desc(step: CinematicLoader.CinematicStep) -> String:
	match step.type:
		"fade_to_black", "fade_from_black":
			return "%s (%s s)" % [STEP_LABEL.get(step.type, step.type), step.params.get("duration", "?")]
		"wait":
			return "Esperar %s s" % step.params.get("seconds", "?")
		"dialogue":
			return "Dialogo: %s" % str(step.params.get("id", "?"))
		"move_node":
			var to: Array = step.params.get("to", [0, 0])
			var x = to[0] if to.size() > 0 else "?"
			var y = to[1] if to.size() > 1 else "?"
			return "Mover %s -> (%s, %s)" % [step.params.get("node", "?"), x, y]
		"show_node":  return "Mostrar: %s" % step.params.get("node", "?")
		"hide_node":  return "Ocultar: %s" % step.params.get("node", "?")
		"disable_player": return "Bloquear jugador"
		"enable_player":  return "Liberar jugador"
		"change_scene":   return "Cambiar a: %s" % str(step.params.get("path", "?")).get_file()
	return step.type


func _refresh_detail() -> void:
	for child in _detail_panel.get_children():
		child.queue_free()

	if _sel < 0 or _sel >= _data.steps.size():
		var lbl := _make_label("Selecciona un paso para editarlo.")
		_detail_panel.add_child(lbl)
		return

	var step: CinematicLoader.CinematicStep = _data.steps[_sel]
	var hdr := _make_section_label("Tipo: %s" % STEP_LABEL.get(step.type, step.type))
	_detail_panel.add_child(hdr)
	_build_step_form(step)


func _refresh_json() -> void:
	if _data == null:
		return
	_data.id = _id_edit.text.strip_edges()
	_json_preview.text = JSON.stringify(CinematicLoader.data_to_dict(_data), "\t")


func _set_status(msg: String) -> void:
	_status_label.text = msg


# ── Formulario dinámico del paso ──────────────────────────────────────────────

func _build_step_form(step: CinematicLoader.CinematicStep) -> void:
	match step.type:
		"fade_to_black", "fade_from_black":
			_field_float(step, "duration", "Duracion (s):", 0.0, 30.0, 0.05)

		"wait":
			_field_float(step, "seconds", "Segundos:", 0.0, 120.0, 0.1)

		"dialogue":
			_field_file(step, "path", "Archivo JSON:")
			_field_string(step, "id", "ID del dialogo:")

		"move_node":
			_field_string(step, "node", "NodePath del nodo:")
			_field_vec2(step)
			_field_float(step, "duration", "Duracion (s):", 0.0, 30.0, 0.05)

		"show_node", "hide_node":
			_field_string(step, "node", "NodePath del nodo:")

		"disable_player", "enable_player":
			var info := _make_label("(Sin parametros adicionales)")
			_detail_panel.add_child(info)

		"change_scene":
			_field_string(step, "path", "Ruta de escena (.tscn):")


func _field_float(step: CinematicLoader.CinematicStep, key: String, label_text: String,
		min_v: float, max_v: float, step_v: float) -> void:
	var row := HBoxContainer.new()
	_detail_panel.add_child(row)

	var lbl := _make_label(label_text)
	lbl.custom_minimum_size.x = 150
	row.add_child(lbl)

	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step_v
	spin.value = float(step.params.get(key, 0.0))
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(func(v: float) -> void:
		step.params[key] = v
		_refresh_step_list()
		_refresh_json()
	)
	row.add_child(spin)


func _field_string(step: CinematicLoader.CinematicStep, key: String, label_text: String) -> void:
	var row := HBoxContainer.new()
	_detail_panel.add_child(row)

	var lbl := _make_label(label_text)
	lbl.custom_minimum_size.x = 150
	row.add_child(lbl)

	var edit := LineEdit.new()
	edit.text = str(step.params.get(key, ""))
	edit.placeholder_text = key
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(v: String) -> void:
		step.params[key] = v
		_refresh_step_list()
		_refresh_json()
	)
	row.add_child(edit)


func _field_file(step: CinematicLoader.CinematicStep, key: String, label_text: String) -> void:
	var row := HBoxContainer.new()
	_detail_panel.add_child(row)

	var lbl := _make_label(label_text)
	lbl.custom_minimum_size.x = 150
	row.add_child(lbl)

	var edit := LineEdit.new()
	edit.text = str(step.params.get(key, ""))
	edit.placeholder_text = "res://assets/cinematics/dialogo.json"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(v: String) -> void:
		step.params[key] = v
		_refresh_json()
	)
	row.add_child(edit)

	var browse_btn := Button.new()
	browse_btn.text = "..."
	browse_btn.pressed.connect(func() -> void:
		_asset_target_edit = edit
		_file_dialog_asset.popup_centered_ratio(0.7)
	)
	row.add_child(browse_btn)


func _field_vec2(step: CinematicLoader.CinematicStep) -> void:
	var row := HBoxContainer.new()
	_detail_panel.add_child(row)

	var lbl := _make_label("Destino (x, y):")
	lbl.custom_minimum_size.x = 150
	row.add_child(lbl)

	var to_arr: Array = step.params.get("to", [0.0, 0.0])

	var spin_x := SpinBox.new()
	spin_x.min_value = -9999.0
	spin_x.max_value =  9999.0
	spin_x.step = 1.0
	spin_x.value = float(to_arr[0]) if to_arr.size() > 0 else 0.0
	spin_x.name = "_sx"
	spin_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin_x)

	var spin_y := SpinBox.new()
	spin_y.min_value = -9999.0
	spin_y.max_value =  9999.0
	spin_y.step = 1.0
	spin_y.value = float(to_arr[1]) if to_arr.size() > 1 else 0.0
	spin_y.name = "_sy"
	spin_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin_y)

	# Closure que actualiza step.params["to"] leyendo ambos spinboxes.
	var update := func() -> void:
		var sx := row.get_node_or_null("_sx") as SpinBox
		var sy := row.get_node_or_null("_sy") as SpinBox
		if sx and sy:
			step.params["to"] = [sx.value, sy.value]
		_refresh_step_list()
		_refresh_json()

	spin_x.value_changed.connect(func(_v): update.call())
	spin_y.value_changed.connect(func(_v): update.call())
