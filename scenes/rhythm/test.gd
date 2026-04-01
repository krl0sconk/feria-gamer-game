extends Node2D


func _ready():
    var arrow = preload("res://scenes/rhythm/NoteArrow.tscn").instantiate()
    arrow.direction = NoteArrow.Direction.UP
    arrow.position = Vector2(200, 0)
    $Notes.add_child(arrow)
