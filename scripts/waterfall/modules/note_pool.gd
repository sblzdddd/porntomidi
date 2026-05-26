extends RefCounted
class_name NotePool

const MAX_POOL_SIZE := 1024

static var _idle_notes: Array[Note] = []
static var _active_note_ids: Dictionary = {}
static var _orphan_notes_count: int = 0
static var _freed_notes_count: int = 0
static var _released_notes_count: int = 0

static func acquire(note_prefab: PackedScene, owner: Node) -> Note:
	while not _idle_notes.is_empty():
		var candidate: Note = _idle_notes.pop_back()
		if is_instance_valid(candidate):
			if candidate.get_parent() != owner:
				if candidate.get_parent() != null:
					candidate.reparent(owner)
				else:
					owner.add_child(candidate)
			_active_note_ids[candidate.get_instance_id()] = true
			return candidate
		_orphan_notes_count += 1
	var created: Note = note_prefab.instantiate() as Note
	owner.add_child(created)
	_active_note_ids[created.get_instance_id()] = true
	return created

static func release(note: Note) -> void:
	if not is_instance_valid(note):
		_orphan_notes_count += 1
		return
	_released_notes_count += 1
	var note_id := note.get_instance_id()
	if not _active_note_ids.has(note_id):
		_orphan_notes_count += 1
	else:
		_active_note_ids.erase(note_id)
	note.prepare_for_pool_reuse()
	if _idle_notes.size() >= MAX_POOL_SIZE:
		_freed_notes_count += 1
		note.queue_free()
		return
	_idle_notes.append(note)

static func clear() -> void:
	for note in _idle_notes:
		if is_instance_valid(note):
			_freed_notes_count += 1
			note.queue_free()
		else:
			_orphan_notes_count += 1
	_idle_notes.clear()

static func get_active_count() -> int:
	return _active_note_ids.size()

static func get_orphan_count() -> int:
	return _idle_notes.size()

static func get_freed_count() -> int:
	return _released_notes_count

static func get_orphaned_invalid_count() -> int:
	return _orphan_notes_count

static func get_physically_freed_count() -> int:
	return _freed_notes_count
