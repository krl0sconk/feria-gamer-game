extends Control

var QUESTS_JSON_PATH: String = "res://resources/data/quests.json"

@onready var _panel: PanelContainer = $QuestPanel
@onready var _toggle_button: Button = $QuestPanel/MarginContainer/VBoxContainer/Header/ToggleButton
@onready var _content: VBoxContainer = $QuestPanel/MarginContainer/VBoxContainer/Content
@onready var _quest_description: Label = $QuestPanel/MarginContainer/VBoxContainer/Content/QuestDescription
@onready var _quest_list: ItemList = $QuestPanel/MarginContainer/VBoxContainer/Content/ItemList

var _expanded: bool = true
var _expanded_height: float = 186.0
var _collapsed_height: float = 56.0
var _connected_to_qm: bool = false
var _connect_attempts: int = 0
var _MAX_CONNECT_ATTEMPTS: int = 12
var _dialogue_runner: DialogueRunner = null
var _hidden_by_dialogue: bool = false


func _ready() -> void:
	print("[QuestHud] _ready() start")
	position = Vector2(24, 24)
	_toggle_button.toggle_mode = true
	# Initial expanded state is controlled by `_expanded` and applied below
	_apply_expanded_state()
	if not _toggle_button.toggled.is_connected(_on_toggle_toggled):
		_toggle_button.toggled.connect(_on_toggle_toggled)
	_connect_quest_manager()
	_connect_dialogue_runner()
	call_deferred("_refresh_quests")
	call_deferred("_try_connect_later")
	_refresh_quests()
	print("[QuestHud] _ready() end, expanded=%s" % _expanded)


func _exit_tree() -> void:
	if _toggle_button != null and _toggle_button.toggled.is_connected(_on_toggle_toggled):
		_toggle_button.toggled.disconnect(_on_toggle_toggled)
	_disconnect_quest_manager()
	_disconnect_dialogue_runner()


func _connect_dialogue_runner() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var runner := scene_root.get_node_or_null("DialogueRunner") as DialogueRunner
	if runner == null:
		return
	_dialogue_runner = runner
	if not _dialogue_runner.dialogue_started.is_connected(_on_dialogue_started):
		_dialogue_runner.dialogue_started.connect(_on_dialogue_started)
	if not _dialogue_runner.dialogue_finished.is_connected(_on_dialogue_finished):
		_dialogue_runner.dialogue_finished.connect(_on_dialogue_finished)
	if _dialogue_runner.is_playing():
		_hidden_by_dialogue = true
		_update_hud_visibility()


func _disconnect_dialogue_runner() -> void:
	if _dialogue_runner == null:
		return
	if _dialogue_runner.dialogue_started.is_connected(_on_dialogue_started):
		_dialogue_runner.dialogue_started.disconnect(_on_dialogue_started)
	if _dialogue_runner.dialogue_finished.is_connected(_on_dialogue_finished):
		_dialogue_runner.dialogue_finished.disconnect(_on_dialogue_finished)
	_dialogue_runner = null


func _on_dialogue_started(_dialogue_id: String) -> void:
	_hidden_by_dialogue = true
	_update_hud_visibility()


func _on_dialogue_finished(_dialogue_id: String) -> void:
	_hidden_by_dialogue = false
	_update_hud_visibility()


func _update_hud_visibility() -> void:
	visible = not _hidden_by_dialogue


func _connect_quest_manager() -> void:
	var qm = get_node_or_null("/root/QuestManager")
	if qm == null:
		_connected_to_qm = false
		return
	_connected_to_qm = true
	print("[QuestHud] connected to QuestManager")
	if not qm.quests_loaded.is_connected(_on_quests_loaded):
		qm.quests_loaded.connect(_on_quests_loaded)
	if not qm.active_quests_changed.is_connected(_on_active_quests_changed):
		qm.active_quests_changed.connect(_on_active_quests_changed)
	if not qm.quest_activated.is_connected(_on_quest_state_changed):
		qm.quest_activated.connect(_on_quest_state_changed)
	if not qm.quest_completed.is_connected(_on_quest_state_changed):
		qm.quest_completed.connect(_on_quest_state_changed)
	# ensure HUD refresh after connecting
	_refresh_quests()
	

func _try_connect_later() -> void:
	if _connected_to_qm:
		return
	_connect_attempts += 1
	if _connect_attempts > _MAX_CONNECT_ATTEMPTS:
		print("[QuestHud] giving up connecting to QuestManager after %d attempts" % _connect_attempts)
		return
	_connect_quest_manager()
	if not _connected_to_qm:
		call_deferred("_try_connect_later")


func _disconnect_quest_manager() -> void:
	var qm = get_node_or_null("/root/QuestManager")
	if qm == null:
		return
	if qm.quests_loaded.is_connected(_on_quests_loaded):
		qm.quests_loaded.disconnect(_on_quests_loaded)
	if qm.active_quests_changed.is_connected(_on_active_quests_changed):
		qm.active_quests_changed.disconnect(_on_active_quests_changed)
	if qm.quest_activated.is_connected(_on_quest_state_changed):
		qm.quest_activated.disconnect(_on_quest_state_changed)
	if qm.quest_completed.is_connected(_on_quest_state_changed):
		qm.quest_completed.disconnect(_on_quest_state_changed)


func _on_active_quests_changed(_active_ids: Array[String]) -> void:
	_refresh_quests()


func _on_quests_loaded(_total: int) -> void:
	print("[QuestHud] quests_loaded signal received: total=%d" % _total)
	_refresh_quests()


func _on_quest_state_changed(_quest_id: String) -> void:
	print("[QuestHud] quest state changed: %s" % _quest_id)
	_refresh_quests()


func _on_toggle_toggled(button_pressed: bool) -> void:
	print("[QuestHud] toggled signal received: %s" % button_pressed)
	_expanded = button_pressed
	_apply_expanded_state()


func _apply_expanded_state() -> void:
	_content.visible = _expanded
	_toggle_button.text = "-" if _expanded else "+"
	_panel.custom_minimum_size = Vector2(368, _expanded_height if _expanded else _collapsed_height)
	_panel.size = Vector2(_panel.size.x, _expanded_height if _expanded else _collapsed_height)


func _refresh_quests() -> void:
	_quest_list.clear()
	# Ocultamos la descripción superior: mostramos la jerarquía directamente
	_quest_description.text = ""
	_quest_description.visible = false

	# Obtenemos las quests en runtime (activas o todas si no hay activas)
	var quests_to_show: Array[Quest] = _get_runtime_quests()
	print("[QuestHud] refreshing quests, found=%d" % quests_to_show.size())
	# Filtrar: solo mostrar quests "principales" (x.y.0) y secundarias (x-y).
	var main_quests: Array = []
	var secondary_quests: Array = []
	var intro_quest: Quest = null
	for quest in quests_to_show:
		if quest.id == "quest_intro":
			intro_quest = quest
		# Solo mostrar visibles (ocultas y desactivadas quedan fuera del HUD).
		if quest.visibility_state != Quest.QuestVisibility.VISIBLE:
			continue
		if _is_main_quest_id(quest.id):
			main_quests.append(quest)
		elif _is_secondary_quest_id(quest.id):
			secondary_quests.append(quest)

	var has_any_visible_quest: bool = (main_quests.size() + secondary_quests.size()) > 0
	var first_description: String = ""

	# Añadir quests principales primero
	for quest in main_quests:
		var status_text: String = _get_status_text(quest.progress_state)
		_quest_list.add_item("%s [%s]" % [quest.title, status_text])
		var item_index: int = _quest_list.item_count - 1
		# Construir tooltip con descripción + list of subquests
		var tt: String = "%s\n%s" % [quest.title, quest.description]
		var subs: Array = _get_subquests_for_main(quest.id)
		if subs.size() > 0:
			tt += "\n\nSubmisiones:"
			for s in subs:
				var s_status := _get_status_text(s.progress_state)
				tt += "\n - %s [%s]" % [s.title, s_status]
		_quest_list.set_item_tooltip(item_index, tt)
		if first_description.is_empty() and not quest.description.is_empty():
			first_description = quest.description

		# Añadir submisiones como entradas indentadas justo debajo
		for s in subs:
			var s_status2: String = _get_status_text(s.progress_state)
			# Indentar visualmente con un guión y espacios
			_quest_list.add_item("    - %s [%s]" % [s.title, s_status2])
			var sub_idx := _quest_list.item_count - 1
			_quest_list.set_item_tooltip(sub_idx, "%s\n%s" % [s.title, s.description])

	# Luego las secundarias (si las hay)
	for quest in secondary_quests:
		var status_text2: String = _get_status_text(quest.progress_state)
		_quest_list.add_item("%s [%s]" % [quest.title, status_text2])
		var idx2: int = _quest_list.item_count - 1
		_quest_list.set_item_tooltip(idx2, "%s\n%s" % [quest.title, quest.description])
		if first_description.is_empty() and not quest.description.is_empty():
			first_description = quest.description

	if has_any_visible_quest:
		_update_toggle_label()
		return

	if intro_quest != null:
		_quest_list.add_item("%s [%s]" % [intro_quest.title, _get_status_text(intro_quest.progress_state)])
		_quest_list.set_item_tooltip(0, "%s\n%s" % [intro_quest.title, intro_quest.description])
		_update_toggle_label()
		return

	_quest_list.add_item("Sin misiones activas")
	_quest_list.set_item_disabled(0, true)
	_quest_description.visible = false
	# opcional: tooltip para indicar cómo desbloquear
	_quest_list.set_item_tooltip(0, "Explora para desbloquear misiones.")
	_update_toggle_label()


func _update_toggle_label() -> void:
	_toggle_button.text = "-" if _expanded else "+"


func _get_status_text(state: Quest.QuestState) -> String:
	match state:
		Quest.QuestState.ACTIVADA:
			return "Activa"
		Quest.QuestState.EN_CURSO:
			return "En curso"
		Quest.QuestState.COMPLETADA:
			return "Completada"
		_:
			return "Desconocida"


func _get_runtime_quests() -> Array[Quest]:
	var result: Array[Quest] = []
	if QuestManager != null:
		var active_quests: Array[Quest] = QuestManager.get_active_quests()
		if not active_quests.is_empty():
			return active_quests
		var all_quests: Array[Quest] = QuestManager.get_all_quests()
		if not all_quests.is_empty():
			return all_quests

	var json_quests: Array[Quest] = _load_quests_from_json()
	for quest in json_quests:
		result.append(quest)
	return result


func _load_quests_from_json() -> Array[Quest]:
	var result: Array[Quest] = []
	if not FileAccess.file_exists(QUESTS_JSON_PATH):
		return result

	var text: String = FileAccess.get_file_as_string(QUESTS_JSON_PATH)
	if text.is_empty():
		return result

	var json := JSON.new()
	if json.parse(text) != OK:
		return result
	if typeof(json.data) != TYPE_DICTIONARY:
		return result

	var root: Dictionary = json.data
	var raw_quests_variant: Variant = root.get("quests", [])
	if typeof(raw_quests_variant) != TYPE_ARRAY:
		return result

	for raw_variant in raw_quests_variant:
		if typeof(raw_variant) != TYPE_DICTIONARY:
			continue
		var raw: Dictionary = raw_variant
		var q := Quest.new()
		q.id = str(raw.get("id", "")).strip_edges()
		q.title = str(raw.get("title", ""))
		q.description = str(raw.get("description", ""))
		q.visibility_state = int(raw.get("visibility_state", Quest.QuestVisibility.OCULTA))
		q.progress_state = int(raw.get("progress_state", Quest.QuestState.ACTIVADA))
		var req_variant: Variant = raw.get("requires_ids", [])
		if typeof(req_variant) == TYPE_ARRAY:
			for req_id in req_variant:
				q.requires_ids.append(str(req_id).strip_edges())
		result.append(q)

	return result


func _is_main_quest_id(qid: String) -> bool:
	if qid == null:
		return false
	var id := str(qid).strip_edges()
	if id.find(".") == -1:
		return false
	var parts := id.split(".")
	if parts.size() != 3:
		return false
	return parts[2] == "0"


func _is_secondary_quest_id(qid: String) -> bool:
	if qid == null:
		return false
	var id := str(qid).strip_edges()
	return id.find("-") != -1


func _get_subquests_for_main(main_id: String) -> Array:
	var out: Array = []
	if QuestManager == null:
		return out
	var all: Array = QuestManager.get_all_quests()
	# main_id expected like "x.y.0" -> prefix "x.y."
	var prefix := ""
	if main_id.find(".") != -1:
		var parts := main_id.split(".")
		if parts.size() == 3:
			prefix = "%s.%s." % [parts[0], parts[1]]
	if prefix == "":
		return out
	for q in all:
		if q.visibility_state == Quest.QuestVisibility.DESACTIVADA:
			continue
		var id := str(q.id)
		if id.begins_with(prefix) and not _is_main_quest_id(id):
			out.append(q)
	return out
