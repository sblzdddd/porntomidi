extends Panel
class_name Note

const PLAY_PARTICLE_PREFAB = preload("res://prefabs/play_particle.tscn")
const PLAY_PARTICLE_GROUP := "note_play_particles"

@export var waterfall_speed: float = 1.0
# the span of waterfall in timestamp units
@export var waterfall_span: Vector2 = Vector2.ZERO
@export var pool_base: float = 0.0
@export var pitch: int = 0
@export var falls_down: bool = false
var use_fixed_span := false
var fixed_span_start_ms: float = 0.0
var fixed_span_end_ms: float = 0.0
var ended = false
var play_particle: GPUParticles2D = null
var play_particle_stopping := false
var note_tint: Color = Color.WHITE
var channel_id: int = -1

static var _idle_particles_by_channel: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func init(set_pitch: int, set_falls_down: bool = false, set_channel_id: int = -1) -> void:
	PianoConfig.config_changed.connect(_update_settings)
	_update_settings(false)
	waterfall_span.x = Time.get_ticks_msec()
	self.pitch = set_pitch
	self.falls_down = set_falls_down
	self.use_fixed_span = false
	self.channel_id = set_channel_id

func init_fixed_span_down(set_pitch: int, start_ms: float, end_ms: float, tint: Color, set_channel_id: int = -1) -> void:
	init(set_pitch, true, set_channel_id)
	self.use_fixed_span = true
	self.fixed_span_start_ms = start_ms
	self.fixed_span_end_ms = max(start_ms + 1.0, end_ms)
	apply_tint(tint)

func apply_tint(tint: Color) -> void:
	note_tint = tint
	_apply_tint(tint)
	_apply_particle_tint()


func _update_settings(_force: bool):
	self.waterfall_speed = PianoConfig.waterfall_speed
	self.pool_base = PianoConfig.waterfall_bottom


func end_note():
	if ended: return
	waterfall_span.y = Time.get_ticks_msec()
	ended = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var time = Time.get_ticks_msec()
	if !ended: waterfall_span.y = time
	var pos_x = PianoConfig.key_coords[pitch-PianoConfig.start_pitch].x
	var size_x = PianoConfig.key_coords[pitch-PianoConfig.start_pitch].y
	var pos_y: float
	var size_y: float
	if falls_down and use_fixed_span:
		var y_start = pool_base - (fixed_span_start_ms - time) * waterfall_speed / 4
		var y_end = pool_base - (fixed_span_end_ms - time) * waterfall_speed / 4
		pos_y = min(y_start, y_end)
		size_y = abs(y_end - y_start)
	elif falls_down:
		pos_y = (time - waterfall_span.y) * waterfall_speed / 4
		size_y = (time - waterfall_span.x) * waterfall_speed / 4 - pos_y
	else:
		pos_y = pool_base - (time - waterfall_span.x) * waterfall_speed / 4
		size_y = pool_base - (time - waterfall_span.y) * waterfall_speed / 4 - pos_y
	_update_play_particle(time, pos_x, size_x)
	set_position(Vector2(pos_x, pos_y))
	set_size(Vector2(size_x, size_y))
	if falls_down and use_fixed_span and pos_y > pool_base:
		_stop_play_particle()
		queue_free()
	elif ended and ((falls_down and pos_y > pool_base) or (not falls_down and (pos_y + size_y) < 0)):
		_stop_play_particle()
		queue_free()

func _update_play_particle(time_ms: float, pos_x: float, size_x: float) -> void:
	var max_particles := PianoConfig.play_particle_max_count
	if max_particles == 0: return
	var note_is_on := _is_note_on(time_ms)
	if note_is_on and play_particle == null:
		play_particle = _take_idle_particle(channel_id)
		if play_particle == null:
			var tree := get_tree()
			if max_particles > 0 and tree != null and tree.get_nodes_in_group(PLAY_PARTICLE_GROUP).size() >= max_particles:
				return
			play_particle = PLAY_PARTICLE_PREFAB.instantiate() as GPUParticles2D
			play_particle.add_to_group(PLAY_PARTICLE_GROUP)
		play_particle_stopping = false
		var parent_node := get_parent()
		if parent_node != null and play_particle.get_parent() != parent_node:
			if play_particle.get_parent() != null:
				play_particle.reparent(parent_node)
			else:
				parent_node.add_child(play_particle)
		elif parent_node == null and play_particle.get_parent() == null:
			add_child(play_particle)
		elif parent_node != null and play_particle.get_parent() == null:
			parent_node.add_child(play_particle)
		_apply_particle_tint()
	if play_particle == null:
		return
	play_particle.position = Vector2(pos_x + size_x * 0.5, pool_base)
	if note_is_on:
		play_particle.emitting = true
	else:
		_stop_play_particle()

func _is_note_on(time_ms: float) -> bool:
	if falls_down and use_fixed_span:
		return time_ms >= fixed_span_start_ms and time_ms <= fixed_span_end_ms
	return not ended

func _stop_play_particle() -> void:
	if not is_instance_valid(play_particle):
		play_particle = null
		play_particle_stopping = false
		return
	if not play_particle_stopping:
		play_particle_stopping = true
		play_particle.emitting = false
		_store_idle_particle(channel_id, play_particle)
	play_particle = null
	play_particle_stopping = false

func _apply_particle_tint() -> void:
	if not is_instance_valid(play_particle):
		return
	play_particle.modulate = note_tint
	if play_particle.process_material is ParticleProcessMaterial:
		var source_material := play_particle.process_material as ParticleProcessMaterial
		var local_material := source_material.duplicate() as ParticleProcessMaterial
		local_material.color = note_tint.lightened(0.25) * 1.3
		play_particle.process_material = local_material

func _apply_tint(tint: Color) -> void:
	var stylebox := get_theme_stylebox("panel")
	if stylebox is StyleBoxFlat:
		var local_style: StyleBoxFlat = (stylebox as StyleBoxFlat).duplicate()
		local_style.bg_color = Color(tint.r, tint.g, tint.b, local_style.bg_color.a)
		var border_tint := tint.lightened(0.25) * 1.2

		local_style.border_color = Color(border_tint.r, border_tint.g, border_tint.b, local_style.border_color.a)
		add_theme_stylebox_override("panel", local_style)

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
