class_name ChartLoader
extends RefCounted

class PhaseData:
	var bpm: float = 120.0
	var audio_path: String = ""
	var start_ms: float = 0.0
	var transition_dialogue_path: String = ""
	var transition_dialogue_id: String = ""

class ChartData:
	var title: String = ""
	var phases: Array = []  # Array[PhaseData], always >= 1 element
	var notes: Array[NoteData] = []

	func get_bpm_at(ms: float) -> float:
		if phases.is_empty():
			return 120.0
		var result = phases[0]
		for p in phases:
			if p.start_ms <= ms:
				result = p
		return result.bpm

	func get_phase_at(ms: float) -> int:
		var idx := 0
		for i in range(phases.size()):
			if phases[i].start_ms <= ms:
				idx = i
		return idx


static func load_json(path: String) -> ChartData:
	var result := ChartData.new()

	if not FileAccess.file_exists(path):
		push_error("ChartLoader: archivo no encontrado: %s" % path)
		return result

	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("ChartLoader: archivo vacío: %s" % path)
		return result

	var json := JSON.new()
	var parse_error: int = json.parse(text)
	if parse_error != OK:
		push_error("ChartLoader: error al parsear %s (línea %d): %s" % [
			path, json.get_error_line(), json.get_error_message()
		])
		return result

	var data: Dictionary = json.data
	result.title = str(data.get("title", ""))

	if data.has("phases"):
		for raw_p in data["phases"]:
			var p := PhaseData.new()
			p.bpm = float(raw_p.get("bpm", 120.0))
			p.audio_path = str(raw_p.get("audio", ""))
			p.start_ms = float(raw_p.get("start_ms", 0.0))
			var raw_t: Dictionary = raw_p.get("transition", {})
			p.transition_dialogue_path = str(raw_t.get("dialogue_path", ""))
			p.transition_dialogue_id   = str(raw_t.get("dialogue_id", ""))
			result.phases.append(p)
	else:
		var p := PhaseData.new()
		p.bpm = float(data.get("bpm", 120.0))
		result.phases.append(p)

	var raw_notes: Array = data.get("notes", [])
	for raw in raw_notes:
		var note := NoteData.new()
		note.time_ms = float(raw.get("time_ms", 0.0))
		note.action = str(raw.get("action", ""))
		note.is_fake = bool(raw.get("is_fake", false))
		result.notes.append(note)

	result.notes.sort_custom(func(a: NoteData, b: NoteData) -> bool:
		return a.time_ms < b.time_ms
	)

	return result


static func save_json(path: String, chart_data: ChartData) -> void:
	var notes_array: Array = []
	for note in chart_data.notes:
		notes_array.append({"time_ms": note.time_ms, "action": note.action, "is_fake": note.is_fake})

	var phases_array: Array = []
	for p in chart_data.phases:
		phases_array.append({"bpm": p.bpm, "audio": p.audio_path, "start_ms": p.start_ms})

	var data: Dictionary = {
		"title": chart_data.title,
		"phases": phases_array,
		"notes": notes_array,
	}

	var json_string: String = JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("ChartLoader: no se pudo escribir: %s" % path)
		return
	file.store_string(json_string)
