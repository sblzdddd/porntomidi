extends Control

const NOTE_PREFAB = preload("res://prefabs/note.tscn")
const NOTE_POOL_PREWARM_COUNT := 2000

var waterfalls_up: Dictionary[int, Dictionary] = {}
var active_down_notes: Dictionary = {}
var midi_player: MidiPlayer = null

var playback_note_spans: Array = []
var playback_spawn_index: int = 0
var playback_last_position: float = -1.0
var playback_cached_events: Array = []
var _notify_config_pending := false
var _recycle_note_callback: Callable = Callable()

func _ready() -> void:
	MidiEvents.control_change.connect(resize)
	MidiEvents.note_on_channel.connect(on_note_on_channel)
	MidiEvents.note_off_channel.connect(on_note_off_channel)
	midi_player = get_node_or_null("../../MidiPlayer")
	if midi_player != null:
		midi_player.finished.connect(_on_playback_finished)
		_rebuild_playback_cache()
	_recycle_note_callback = Callable(self, "_recycle_note")
	NotePool.setup(self, NOTE_PREFAB, NOTE_POOL_PREWARM_COUNT)
	notify_config()
	get_window().size_changed.connect(notify_config)

func resize(id:int, value:int):
	if id == 13:
		var p = (float(value)) / 140
		size_flags_stretch_ratio = p / (1-p)
		notify_config()
	elif id == 14:
		PianoConfig.waterfall_speed = (float(value+32) / 64)

func notify_config():
	if _notify_config_pending:
		return
	_notify_config_pending = true
	await get_tree().process_frame
	_notify_config_pending = false
	var base = get_transform().get_origin().y + size.y
	PianoConfig.waterfall_bottom = base

func _process(_delta: float) -> void:
	if midi_player == null:
		return
	if midi_player.track_status == null or midi_player.track_status.events == null:
		return

	if not is_same(playback_cached_events, midi_player.track_status.events):
		_rebuild_playback_cache()
		return

	if not midi_player.playing:
		playback_last_position = midi_player.position
		return

	if playback_last_position >= 0.0 and midi_player.position + 1.0 < playback_last_position:
		_resync_playback_spawn_cursor()
		_clear_down_waterfalls()

	_spawn_scheduled_playback_notes()
	playback_last_position = midi_player.position

func on_note_on_channel(channel: int, pitch: int, _velocity: int):
	var tint: Color = ChannelColorAllocator.get_color(channel)
	_start_note(pitch, false, waterfalls_up, tint, channel)

func _start_note(pitch: int, falls_down: bool, registry: Dictionary, tint: Color = Color(0, 0, 0, 0), channel: int = -1):
	if PianoConfig.in_range(pitch):
		var note: Note = NotePool.acquire(NOTE_PREFAB, self)
		note.set_release_callback(_recycle_note_callback)
		note.init(pitch, falls_down, channel)
		if tint.a > 0.0:
			note.apply_tint(tint)
		var pitch_queue: Dictionary = _get_or_create_pitch_queue(registry, pitch)
		QueueState.push(pitch_queue, note)

func on_note_off_channel(_channel: int, pitch: int):
	_end_note(pitch, waterfalls_up)

func _end_note(pitch: int, registry: Dictionary):
	if PianoConfig.in_range(pitch) and registry.has(pitch):
		var pitch_notes: Dictionary = registry[pitch]
		var note: Note = _pop_valid_note(pitch_notes)
		if note != null:
			note.end_note()
		if QueueState.is_empty(pitch_notes):
			registry.erase(pitch)

func _pop_valid_note(queue: Dictionary) -> Note:
	while not QueueState.is_empty(queue):
		var note = QueueState.pop(queue) as Note
		if is_instance_valid(note):
			return note
	return null

func _get_or_create_pitch_queue(registry: Dictionary, pitch: int) -> Dictionary:
	if not registry.has(pitch):
		registry[pitch] = QueueState.create()
	return registry[pitch]

func _recycle_note(note: Note) -> void:
	if note == null:
		return
	var note_id := note.get_instance_id()
	if active_down_notes.has(note_id):
		active_down_notes.erase(note_id)
	NotePool.release(note)

func _rebuild_playback_cache() -> void:
	playback_note_spans.clear()
	playback_spawn_index = 0
	playback_last_position = midi_player.position if midi_player != null else -1.0
	playback_cached_events = []
	ChannelColorAllocator.reset()

	if midi_player == null or midi_player.track_status == null or midi_player.track_status.events == null:
		return

	playback_cached_events = midi_player.track_status.events
	playback_note_spans = PlaybackSpanBuilder.build(playback_cached_events)
	_resync_playback_spawn_cursor()

func _spawn_scheduled_playback_notes() -> void:
	if playback_note_spans.is_empty() or midi_player == null or midi_player.smf_data == null:
		return
	var lookahead_timebase: float = _get_lookahead_timebase()
	var now_pos: float = midi_player.position
	var spawn_until: float = now_pos + lookahead_timebase
	while playback_spawn_index < playback_note_spans.size():
		var span = playback_note_spans[playback_spawn_index]
		if span.start_time > spawn_until:
			break
		_spawn_playback_span(span)
		playback_spawn_index += 1

func _spawn_playback_span(span) -> void:
	var pitch: int = span.note
	if not PianoConfig.in_range(pitch):
		return
	var note: Note = NotePool.acquire(NOTE_PREFAB, self)
	note.set_release_callback(_recycle_note_callback)
	var now_ms: float = float(Time.get_ticks_msec())
	var start_ms: float = now_ms + _timebase_delta_to_ms(span.start_time - midi_player.position)
	var end_ms: float = now_ms + _timebase_delta_to_ms(span.end_time - midi_player.position)
	var channel: int = span.channel
	var tint: Color = ChannelColorAllocator.get_color(channel)
	note.init_fixed_span_down(pitch, start_ms, end_ms, tint, channel)
	active_down_notes[note.get_instance_id()] = note

func _timebase_delta_to_ms(delta_timebase: float) -> float:
	if midi_player == null or midi_player.smf_data == null:
		return 0.0
	var units_per_second: float = float(midi_player.smf_data.timebase) * midi_player.seconds_to_timebase * midi_player.play_speed
	if units_per_second <= 0.0001:
		return 0.0
	return (delta_timebase / units_per_second) * 1000.0

func _get_lookahead_timebase() -> float:
	if midi_player == null or midi_player.smf_data == null:
		return 0.0
	var px_speed: float = max(0.001, PianoConfig.waterfall_speed)
	var lead_ms: float = max(0.0, PianoConfig.waterfall_bottom * 4.0 / px_speed)
	var lead_seconds: float = lead_ms / 1000.0
	return float(midi_player.smf_data.timebase) * lead_seconds * midi_player.seconds_to_timebase * midi_player.play_speed

func _resync_playback_spawn_cursor() -> void:
	playback_spawn_index = 0
	if playback_note_spans.is_empty() or midi_player == null:
		return
	var lookahead_timebase: float = _get_lookahead_timebase()
	var min_start: float = midi_player.position - lookahead_timebase
	while playback_spawn_index < playback_note_spans.size():
		if playback_note_spans[playback_spawn_index].start_time >= min_start:
			break
		playback_spawn_index += 1

func _clear_down_waterfalls() -> void:
	for note in active_down_notes.values():
		var down_note = note as Note
		if is_instance_valid(down_note):
			down_note.set_release_callback(Callable())
			NotePool.release(down_note)
	active_down_notes.clear()

func _on_playback_finished() -> void:
	_clear_down_waterfalls()


func _exit_tree() -> void:
	_clear_down_waterfalls()
	for queue in waterfalls_up.values():
		while not QueueState.is_empty(queue):
			var note = QueueState.pop(queue) as Note
			if is_instance_valid(note):
				note.set_release_callback(Callable())
				NotePool.release(note)
	waterfalls_up.clear()
	NotePool.clear()

func get_status() -> Dictionary:
	var events_total := 0
	var event_pointer := 0
	if not(midi_player == null or midi_player.track_status == null or midi_player.track_status.events == null):
		events_total = midi_player.track_status.events.size()
		event_pointer = midi_player.track_status.event_pointer
	return {
		"active": NotePool.get_active_count(),
		"orphan": NotePool.get_orphan_count(),
		"freed": NotePool.get_freed_count(),
		"physically_freed": NotePool.get_physically_freed_count(),
		"events_total": events_total,
		"event_pointer": event_pointer,
		"remaining": max(0, events_total - event_pointer),
		"position": midi_player.position,
		"playing": midi_player.playing
	}
