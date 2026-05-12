extends RefCounted
class_name NotePool

const DEFAULT_PREWARM_COUNT := 2000
const POOL_ROOT_NAME := "NotePoolContainer"

static var _idle_notes: Array[Note] = []
static var _active_note_ids: Dictionary = {}
static var _pool_root: Node = null
static var _orphan_notes_count: int = 0
static var _freed_notes_count: int = 0
static var _released_notes_count: int = 0

static func setup(owner: Node, note_prefab: PackedScene, prewarm_count: int = DEFAULT_PREWARM_COUNT) -> void:
	_ensure_pool_root(owner)
	if note_prefab == null:
		return
	if _idle_notes.size() >= prewarm_count:
		return
	var missing := prewarm_count - _idle_notes.size()
	for i in range(missing):
		var note: Note = note_prefab.instantiate() as Note
		_pool_root.add_child(note)
		note.prepare_for_pool_reuse()
		note.set_physics_process(false)
		_idle_notes.append(note)

static func acquire(note_prefab: PackedScene, owner: Node) -> Note:
	_ensure_pool_root(owner)
	if not _idle_notes.is_empty():
		var candidate: Note = _idle_notes.pop_back()
		candidate.visible = true
		candidate.set_process(true)
		candidate.set_physics_process(true)
		_active_note_ids[candidate.get_instance_id()] = true
		return candidate
	var created: Note = note_prefab.instantiate() as Note
	_pool_root.add_child(created)
	created.visible = true
	created.set_process(true)
	created.set_physics_process(true)
	_active_note_ids[created.get_instance_id()] = true
	return created

static func release(note: Note) -> void:
	if note == null:
		_orphan_notes_count += 1
		return
	_released_notes_count += 1
	var note_id := note.get_instance_id()
	if _active_note_ids.has(note_id):
		_active_note_ids.erase(note_id)
	note.prepare_for_pool_reuse()
	note.set_physics_process(false)
	_idle_notes.append(note)

static func clear() -> void:
	for note_id in _active_note_ids.keys():
		var maybe_note := instance_from_id(note_id)
		if maybe_note is Note:
			_freed_notes_count += 1
			(maybe_note as Note).queue_free()
	for note in _idle_notes:
		_freed_notes_count += 1
		note.queue_free()
	_active_note_ids.clear()
	_idle_notes.clear()
	_pool_root = null

static func _ensure_pool_root(owner: Node) -> void:
	if owner == null:
		return
	if _pool_root != null:
		return
	var existing := owner.get_node_or_null(POOL_ROOT_NAME)
	if existing != null:
		_pool_root = existing
		return
	var root := Node.new()
	root.name = POOL_ROOT_NAME
	owner.add_child(root)
	_pool_root = root

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
