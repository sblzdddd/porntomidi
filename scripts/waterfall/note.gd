extends Panel
class_name Note

@export var waterfall_speed: float = 1.0
# the span of waterfall in timestamp units
@export var waterfall_span: Vector2 = Vector2.ZERO
@export var pool_base: float = 0.0
@export var pitch: int = 0
@export var falls_down: bool = false
var fixed_span: Vector2 = Vector2.ZERO
var ended = false
var particle_controller = null
var note_tint: Color = Color.WHITE
var channel_id: int = -1
var _release_callback: Callable = Callable()
var _settings_connected: bool = false

func init(set_pitch: int, set_falls_down: bool = false, set_channel_id: int = -1) -> void:
	if not _settings_connected:
		PianoConfig.config_changed.connect(_update_settings)
		_settings_connected = true
	ended = false
	fixed_span = Vector2.ZERO
	waterfall_span = Vector2.ZERO
	set_process(true)
	visible = true
	_update_settings(false)
	pitch = set_pitch
	falls_down = set_falls_down
	channel_id = set_channel_id
	waterfall_span.x = _now_ms()
	if particle_controller == null:
		particle_controller = NoteParticleController.new(channel_id)
	else:
		particle_controller.set_channel_id(channel_id)
	particle_controller.set_tint(note_tint)

func init_fixed_span_down(set_pitch: int, start_ms: float, end_ms: float, tint: Color, set_channel_id: int = -1) -> void:
	init(set_pitch, true, set_channel_id)
	fixed_span = Vector2(start_ms, max(start_ms + 1.0, end_ms))
	apply_tint(tint)

func apply_tint(tint: Color) -> void:
	note_tint = tint
	_apply_tint(tint)
	if particle_controller != null:
		particle_controller.set_tint(note_tint)

func _update_settings(_force: bool):
	waterfall_speed = PianoConfig.waterfall_speed
	pool_base = PianoConfig.waterfall_bottom

func end_note():
	if ended: return
	waterfall_span.y = _now_ms()
	ended = true

func _process(_delta: float) -> void:
	var time = _now_ms()
	if !ended: waterfall_span.y = time
	var pos_x = PianoConfig.key_coords[pitch-PianoConfig.start_pitch].x
	var size_x = PianoConfig.key_coords[pitch-PianoConfig.start_pitch].y
	var pos_y: float
	var size_y: float
	if falls_down and fixed_span != Vector2.ZERO:
		var y_start = pool_base - (fixed_span.x - time) * waterfall_speed / 4
		var y_end = pool_base - (fixed_span.y - time) * waterfall_speed / 4
		pos_y = min(y_start, y_end)
		size_y = abs(y_end - y_start)
	elif falls_down:
		pos_y = (time - waterfall_span.y) * waterfall_speed / 4
		size_y = (time - waterfall_span.x) * waterfall_speed / 4 - pos_y
	else:
		pos_y = pool_base - (time - waterfall_span.x) * waterfall_speed / 4
		size_y = pool_base - (time - waterfall_span.y) * waterfall_speed / 4 - pos_y

	# update play particle
	if particle_controller == null:
		return
	particle_controller.update(
		self,
		_is_note_on(time),
		pos_x,
		size_x,
		pool_base,
	)

	set_position(Vector2(pos_x, pos_y))
	set_size(Vector2(size_x, size_y))
	if falls_down and fixed_span != Vector2.ZERO and pos_y > pool_base:
		_release_and_free()
	elif ended and ((falls_down and pos_y > pool_base) or (not falls_down and (pos_y + size_y) < 0)):
		_release_and_free()

func _is_note_on(time_ms: float) -> bool:
	if falls_down and fixed_span != Vector2.ZERO:
		return time_ms >= fixed_span.x and time_ms <= fixed_span.y
	return not ended

func _now_ms() -> float:
	return PlaybackClock.now_ms() if falls_down else float(Time.get_ticks_msec())

func _release_and_free() -> void:
	if _release_callback.is_valid():
		_release_callback.call(self)
		return
	queue_free()

func set_release_callback(callback: Callable) -> void:
	_release_callback = callback

func prepare_for_pool_reuse() -> void:
	ended = false
	falls_down = false
	fixed_span = Vector2.ZERO
	waterfall_span = Vector2.ZERO
	set_process(false)
	visible = false
	if particle_controller != null:
		particle_controller.stop()

func _apply_tint(tint: Color) -> void:
	var stylebox := get_theme_stylebox("panel")
	if stylebox is StyleBoxFlat:
		var local_style: StyleBoxFlat = (stylebox as StyleBoxFlat).duplicate()
		local_style.bg_color = Color(tint.r, tint.g, tint.b, local_style.bg_color.a)
		var border_tint := tint.lightened(0.25)

		local_style.border_color = Color(border_tint.r, border_tint.g, border_tint.b, local_style.border_color.a)
		add_theme_stylebox_override("panel", local_style)

func _exit_tree() -> void:
	if particle_controller != null:
		particle_controller.stop()
