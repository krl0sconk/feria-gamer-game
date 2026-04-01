# Lee un archivo JSON y lo convierte en datos de chart listos para el Composer.
#
# Formato esperado del JSON:
# {
#   "title": "Nombre de la canción",
#   "bpm": 120,
#   "notes": [
#     { "time_ms": 1000.0, "action": "note_up" },
#     { "time_ms": 2500.0, "action": "note_left" }
#   ]
# }
#
# Uso:
#   var data := ChartLoader.load_json("res://assets/charts/mi_chart.json")
#   _composer.load_chart(data.notes)
class_name ChartLoader
extends RefCounted

## Contiene el resultado de parsear un archivo de chart.
class ChartData:
	var title: String = ""
	var bpm: float = 120.0
	var notes: Array[NoteData] = []


## Carga y parsea un archivo JSON de chart.
## Devuelve ChartData vacío si ocurre algún error.
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
	result.bpm   = float(data.get("bpm", 120.0))

	var raw_notes: Array = data.get("notes", [])
	for raw in raw_notes:
		var note := NoteData.new()
		note.time_ms = float(raw.get("time_ms", 0.0))
		note.action  = str(raw.get("action", ""))
		result.notes.append(note)

	# Ordenar por time_ms ascendente por si el JSON no estaba en orden
	result.notes.sort_custom(func(a: NoteData, b: NoteData) -> bool:
		return a.time_ms < b.time_ms
	)

	return result


## Guarda un ChartData como JSON. Útil para el editor de charts.
static func save_json(path: String, chart_data: ChartData) -> void:
	var notes_array: Array = []
	for note in chart_data.notes:
		notes_array.append({"time_ms": note.time_ms, "action": note.action})

	var data: Dictionary = {
		"title": chart_data.title,
		"bpm": chart_data.bpm,
		"notes": notes_array,
	}

	var json_string: String = JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("ChartLoader: no se pudo escribir: %s" % path)
		return
	file.store_string(json_string)
