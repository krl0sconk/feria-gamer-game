class_name CircularLinkedList
extends RefCounted


class CircularListNode:
	var value: Variant = null
	var next: CircularListNode = null

	func _init(node_value: Variant) -> void:
		value = node_value


var head: CircularListNode = null
var tail: CircularListNode = null
var _size: int = 0


func clear() -> void:
	head = null
	tail = null
	_size = 0


func is_empty() -> bool:
	return _size == 0


func size() -> int:
	return _size


func append(value: Variant) -> CircularListNode:
	var node := CircularListNode.new(value)
	if head == null:
		head = node
		tail = node
		node.next = node
	else:
		node.next = head
		tail.next = node
		tail = node
	_size += 1
	return node


func get_node_at(index: int) -> CircularListNode:
	if is_empty():
		return null
	var normalized := index % _size
	if normalized < 0:
		normalized += _size
	var current := head
	for _i in range(normalized):
		current = current.next
	return current


func advance_from(node: CircularListNode, steps: int = 1) -> CircularListNode:
	if node == null:
		return null
	var current := node
	for _i in range(max(steps, 0)):
		current = current.next
	return current


func index_of_node(target: CircularListNode) -> int:
	if is_empty() or target == null:
		return -1
	var current := head
	for i in range(_size):
		if current == target:
			return i
		current = current.next
	return -1


func to_array() -> Array:
	var out: Array = []
	if is_empty():
		return out
	var current := head
	for _i in range(_size):
		out.append(current.value)
		current = current.next
	return out