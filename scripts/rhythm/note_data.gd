# Recurso de datos que representa una nota en el chart del nivel.
class_name NoteData
extends Resource

## Momento exacto en milisegundos en que la nota debe ser tocada.
@export var time_ms: float = 0.0
# Valores válidos: "note_left", "note_down", "note_up", "note_right"
@export var action: String = ""
