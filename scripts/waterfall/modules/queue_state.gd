extends RefCounted
class_name QueueState

static func create() -> Dictionary:
	return {
		"items": [],
		"head": 0
	}

static func push(queue: Dictionary, value: Variant) -> void:
	var items: Array = queue["items"]
	items.append(value)
	queue["items"] = items

static func pop(queue: Dictionary) -> Variant:
	var head: int = queue["head"]
	var items: Array = queue["items"]
	if head >= items.size():
		return null
	var value: Variant = items[head]
	head += 1
	queue["head"] = head
	if head >= 32 and head * 2 >= items.size():
		items = items.slice(head, items.size())
		queue["items"] = items
		queue["head"] = 0
	return value

static func peek(queue: Dictionary) -> Variant:
	var head: int = queue["head"]
	var items: Array = queue["items"]
	if head >= items.size():
		return null
	return items[head]

static func is_empty(queue: Dictionary) -> bool:
	return int(queue["head"]) >= (queue["items"] as Array).size()
