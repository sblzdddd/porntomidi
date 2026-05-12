extends RefCounted
class_name NoteParticleController

const PLAY_PARTICLE_PREFAB = preload("res://prefabs/play_particle.tscn")
const PLAY_PARTICLE_GROUP := "note_play_particles"

static var _idle_particles_by_channel: Dictionary = {}

var _channel_id: int = -1
var _particle: GPUParticles2D = null
var _particle_stopping := false
var _tint: Color = Color.WHITE

func _init(channel_id: int = -1) -> void:
	_channel_id = channel_id

func set_channel_id(channel_id: int) -> void:
	_channel_id = channel_id

func set_tint(tint: Color) -> void:
	_tint = tint
	_apply_particle_tint()

func update(note_owner: Node, note_is_on: bool, pos_x: float, size_x: float, pool_base: float, max_particles: int) -> void:
	if max_particles == 0:
		return
	if note_is_on and _particle == null:
		_particle = _take_idle_particle(_channel_id)
		if _particle == null:
			var tree := note_owner.get_tree()
			if max_particles > 0 and tree != null and tree.get_nodes_in_group(PLAY_PARTICLE_GROUP).size() >= max_particles:
				return
			_particle = PLAY_PARTICLE_PREFAB.instantiate() as GPUParticles2D
			_particle.add_to_group(PLAY_PARTICLE_GROUP)
		_particle_stopping = false
		var parent_node := note_owner.get_parent()
		if parent_node != null and _particle.get_parent() != parent_node:
			if _particle.get_parent() != null:
				_particle.reparent(parent_node)
			else:
				parent_node.add_child(_particle)
		elif parent_node == null and _particle.get_parent() == null:
			note_owner.add_child(_particle)
		elif parent_node != null and _particle.get_parent() == null:
			parent_node.add_child(_particle)
		_apply_particle_tint()
	if _particle == null:
		return
	_particle.position = Vector2(pos_x + size_x * 0.5, pool_base)
	if note_is_on:
		_particle.emitting = true
	else:
		stop()

func stop() -> void:
	if not is_instance_valid(_particle):
		_particle = null
		_particle_stopping = false
		return
	if not _particle_stopping:
		_particle_stopping = true
		_particle.emitting = false
		_store_idle_particle(_channel_id, _particle)
	_particle = null
	_particle_stopping = false

func _apply_particle_tint() -> void:
	if not is_instance_valid(_particle):
		return
	_particle.modulate = _tint
	if _particle.process_material is ParticleProcessMaterial:
		var source_material := _particle.process_material as ParticleProcessMaterial
		var local_material := source_material.duplicate() as ParticleProcessMaterial
		local_material.color = _tint.lightened(0.25)
		_particle.process_material = local_material

static func _take_idle_particle(channel: int) -> GPUParticles2D:
	if not _idle_particles_by_channel.has(channel):
		return null
	var pool: Array = _idle_particles_by_channel[channel]
	while not pool.is_empty():
		var candidate = pool.pop_back()
		if is_instance_valid(candidate):
			_idle_particles_by_channel[channel] = pool
			return candidate
	_idle_particles_by_channel.erase(channel)
	return null

static func _store_idle_particle(channel: int, particle: GPUParticles2D) -> void:
	if not is_instance_valid(particle):
		return
	if not _idle_particles_by_channel.has(channel):
		_idle_particles_by_channel[channel] = []
	var pool: Array = _idle_particles_by_channel[channel]
	pool.append(particle)
	_idle_particles_by_channel[channel] = pool
