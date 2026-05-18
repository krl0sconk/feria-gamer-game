extends Node

signal quest_activated(quest_id: String)
signal quest_completed(quest_id: String)
signal active_quests_changed(active_ids: Array[String])
signal quests_loaded(total: int)

@export_file("*.json") var quests_json_path: String = "res://resources/data/quests.json"

var _quests: Array[Quest] = []
var _by_id: Dictionary = {}
var _completed: Dictionary = {}
var _active: Dictionary = {}


func _ready() -> void:
	if load_from_json(quests_json_path):
		start_progression()


func load_from_json(path: String) -> bool:
	_quests.clear()
	_by_id.clear()
	_completed.clear()
	_active.clear()

	if not FileAccess.file_exists(path):
		push_warning("QuestManager: no existe archivo %s" % path)
		return false

	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_warning("QuestManager: archivo vacio %s" % path)
		return false

	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("QuestManager: JSON invalido %s" % path)
		return false

	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("QuestManager: el root del JSON debe ser un objeto.")
		return false
	var root: Dictionary = json.data

	var raw_quests_variant: Variant = root.get("quests", [])
	if typeof(raw_quests_variant) != TYPE_ARRAY:
		push_error("QuestManager: el campo 'quests' debe ser un arreglo.")
		return false
	var raw_quests: Array = raw_quests_variant

	for raw_variant in raw_quests:
		if typeof(raw_variant) != TYPE_DICTIONARY:
			continue
		var raw: Dictionary = raw_variant
		var q := Quest.new()
		q.id = str(raw.get("id", "")).strip_edges()
		q.title = str(raw.get("title", ""))
		q.description = str(raw.get("description", ""))
		q.visibility_state = int(raw.get("visibility_state", Quest.QuestVisibility.OCULTA)) as Quest.QuestVisibility
		q.progress_state = int(raw.get("progress_state", Quest.QuestState.ACTIVADA)) as Quest.QuestState

		var req_variant: Variant = raw.get("requires_ids", [])
		q.requires_ids.clear()
		if typeof(req_variant) == TYPE_ARRAY:
			var req_array: Array = req_variant
			for req_id in req_array:
				q.requires_ids.append(str(req_id).strip_edges())

		_quests.append(q)

	for q in _quests:
		if q.id.is_empty():
			push_warning("QuestManager: hay una quest sin id, se ignora.")
			continue
		if _by_id.has(q.id):
			push_warning("QuestManager: id duplicado %s, se ignora duplicado." % q.id)
			continue
		_by_id[q.id] = q

	quests_loaded.emit(_by_id.size())
	return true


func start_progression() -> void:
	_completed.clear()
	_active.clear()

	for q in _by_id.values():
		(q as Quest).reset_states()

	_refresh_unlocks()


func complete_quest(quest_id: String) -> void:
	if not _active.has(quest_id):
		return

	var q: Quest = _active[quest_id] as Quest
	q.complete()
	_active.erase(quest_id)
	_completed[quest_id] = true
	quest_completed.emit(quest_id)

	_refresh_unlocks()


func is_completed(quest_id: String) -> bool:
	return _completed.has(quest_id)


func is_active(quest_id: String) -> bool:
	return _active.has(quest_id)


func get_active_quests() -> Array[Quest]:
	var result: Array[Quest] = []
	for q in _active.values():
		result.append(q as Quest)
	return result


func get_all_quests() -> Array[Quest]:
	var result: Array[Quest] = []
	for q in _by_id.values():
		result.append(q as Quest)
	return result


func _refresh_unlocks() -> void:
	for q_variant in _by_id.values():
		var q: Quest = q_variant as Quest
		if _completed.has(q.id):
			continue
		if _active.has(q.id):
			continue
		if _can_activate(q):
			q.show()
			q.activate()
			q.start()
			_active[q.id] = q
			quest_activated.emit(q.id)

	active_quests_changed.emit(_active_ids_array())


func _can_activate(q: Quest) -> bool:
	for req_id in q.requires_ids:
		if req_id.is_empty():
			continue
		if not _completed.has(req_id):
			return false
	return true


func _active_ids_array() -> Array[String]:
	var ids: Array[String] = []
	for id_variant in _active.keys():
		ids.append(str(id_variant))
	return ids


## Serialización mínima del estado runtime de las quests para guardado.
func serialize_state() -> Array:
	var out: Array = []
	for q_variant in _by_id.values():
		var q: Quest = q_variant as Quest
		out.append({
			"id": q.id,
			"visibility_state": int(q.visibility_state),
			"progress_state": int(q.progress_state),
		})
	return out


func apply_state(serialized: Array) -> void:
	if typeof(serialized) != TYPE_ARRAY:
		return
	# Reset runtime trackers and apply saved states
	_completed.clear()
	_active.clear()
	for item in serialized:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var id := str(item.get("id", "")).strip_edges()
		if not _by_id.has(id):
			continue
		var q: Quest = _by_id[id] as Quest
		var vs: int = int(item.get("visibility_state", int(q.visibility_state)))
		var ps: int = int(item.get("progress_state", int(q.progress_state)))
		q.set_visibility_state(vs)
		q.set_progress_state(ps)
		if ps == Quest.QuestState.COMPLETADA:
			_completed[id] = true
		else:
			_active[id] = q
	active_quests_changed.emit(_active_ids_array())
