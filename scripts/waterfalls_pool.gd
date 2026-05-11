extends Control

const NOTE_PREFAB = preload("res://prefabs/note.tscn")
const INSTRUMENT_COLOR_ALLOCATOR = preload("res://scripts/instrument_color_allocator.gd")

var waterfalls_up: Dictionary[int, Array] = {}
var waterfalls_down: Dictionary[int, Array] = {}
var midi_player: MidiPlayer = null

var playback_note_spans: Array[Dictionary] = []
var playback_spawn_index: int = 0
var playback_last_position: float = -1.0
var playback_cached_events: Array = []

func _ready() -> void:
	MidiEvents.control_change.connect(resize)
	MidiEvents.note_on_channel.connect(on_note_on_channel)
	MidiEvents.note_off_channel.connect(on_note_off_channel)
	midi_player = get_node_or_null("../../MidiPlayer")
	if midi_player != null:
		midi_player.finished.connect(_on_playback_finished)
		_rebuild_playback_cache()
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
	await get_tree().process_frame
	var base = get_transform().get_origin().y + size.y
	PianoConfig.waterfall_bottom = base

func _process(_delta: float) -> void:
	if midi_player == null:
		return
	if midi_player.track_status == null or midi_player.track_status.events == null:
		return

	if playback_cached_events != midi_player.track_status.events:
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
	var tint: Color = INSTRUMENT_COLOR_ALLOCATOR.get_color(channel)
	_start_note(pitch, false, waterfalls_up, tint, channel)

func _start_note(pitch: int, falls_down: bool, registry: Dictionary, tint: Color = Color(0, 0, 0, 0), channel: int = -1):
	if PianoConfig.in_range(pitch):
		var note: Note = NOTE_PREFAB.instantiate()
		note.init(pitch, falls_down, channel)
		if tint.a > 0.0:
			note.apply_tint(tint)
		add_child(note)
		if not registry.has(pitch):
			registry[pitch] = []
		registry[pitch].append(note)

func on_note_off_channel(_channel: int, pitch: int):
	_end_note(pitch, waterfalls_up)

func _end_note(pitch: int, registry: Dictionary):
	if PianoConfig.in_range(pitch) and registry.has(pitch):
		var pitch_notes: Array = registry[pitch]
		while pitch_notes.size() > 0 and not is_instance_valid(pitch_notes[0]):
			pitch_notes.pop_front()
		if pitch_notes.size() > 0:
			var note: Note = pitch_notes.pop_front()
			if is_instance_valid(note):
				note.end_note()
		if pitch_notes.is_empty():
			registry.erase(pitch)

func _rebuild_playback_cache() -> void:
	playback_note_spans.clear()
	playback_spawn_index = 0
	playback_last_position = midi_player.position if midi_player != null else -1.0
	playback_cached_events = []
	INSTRUMENT_COLOR_ALLOCATOR.reset()

	if midi_player == null or midi_player.track_status == null or midi_player.track_status.events == null:
		return

	playback_cached_events = midi_player.track_status.events

	var pending_notes: Dictionary = {}
	for event_chunk in playback_cached_events:
		var channel: int = event_chunk.channel_number
		var event = event_chunk.event
		match event.type:
			SMF.MIDIEventType.note_on:
				var note_on_event: SMF.MIDIEventNoteOn = event as SMF.MIDIEventNoteOn
				if note_on_event.velocity > 0:
					var key := str(channel) + ":" + str(note_on_event.note)
					var span := {
						"channel": channel,
						"note": note_on_event.note,
						"velocity": note_on_event.velocity,
						"start_time": float(event_chunk.time),
						"end_time": float(event_chunk.time)
					}
					playback_note_spans.append(span)
					if not pending_notes.has(key):
						pending_notes[key] = []
					pending_notes[key].append(span)
				else:
					_close_pending_span(pending_notes, channel, note_on_event.note, float(event_chunk.time))
			SMF.MIDIEventType.note_off:
				var note_off_event: SMF.MIDIEventNoteOff = event as SMF.MIDIEventNoteOff
				_close_pending_span(pending_notes, channel, note_off_event.note, float(event_chunk.time))
			_:
				pass

	for key in pending_notes.keys():
		var queue: Array = pending_notes[key]
		for i in range(queue.size()):
			var span: Dictionary = queue[i]
			span["end_time"] = max(float(span["start_time"]) + 1.0, float(span["end_time"]))

	_resync_playback_spawn_cursor()

func _close_pending_span(pending_notes: Dictionary, channel: int, note: int, end_time: float) -> void:
	var key := str(channel) + ":" + str(note)
	if not pending_notes.has(key):
		return
	var queue: Array = pending_notes[key]
	while queue.size() > 0 and not (queue[0] is Dictionary):
		queue.pop_front()
	if queue.is_empty():
		pending_notes.erase(key)
		return
	var span: Dictionary = queue.pop_front()
	span["end_time"] = max(float(span["start_time"]) + 1.0, end_time)
	if queue.is_empty():
		pending_notes.erase(key)

func _spawn_scheduled_playback_notes() -> void:
	if playback_note_spans.is_empty() or midi_player == null or midi_player.smf_data == null:
		return
	var lookahead_timebase: float = _get_lookahead_timebase()
	var now_pos: float = midi_player.position
	var spawn_until: float = now_pos + lookahead_timebase
	while playback_spawn_index < playback_note_spans.size():
		var span: Dictionary = playback_note_spans[playback_spawn_index]
		var start_time: float = float(span["start_time"])
		if start_time > spawn_until:
			break
		_spawn_playback_span(span)
		playback_spawn_index += 1

func _spawn_playback_span(span: Dictionary) -> void:
	var pitch: int = int(span["note"])
	if not PianoConfig.in_range(pitch):
		return
	var note: Note = NOTE_PREFAB.instantiate()
	var now_ms: float = float(Time.get_ticks_msec())
	var start_ms: float = now_ms + _timebase_delta_to_ms(float(span["start_time"]) - midi_player.position)
	var end_ms: float = now_ms + _timebase_delta_to_ms(float(span["end_time"]) - midi_player.position)
	var channel: int = int(span["channel"])
	var tint: Color = INSTRUMENT_COLOR_ALLOCATOR.get_color(channel)
	note.init_fixed_span_down(pitch, start_ms, end_ms, tint, channel)
	add_child(note)

	if not waterfalls_down.has(pitch):
		waterfalls_down[pitch] = []
	waterfalls_down[pitch].append(note)

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
		if float(playback_note_spans[playback_spawn_index]["start_time"]) >= min_start:
			break
		playback_spawn_index += 1

func _clear_down_waterfalls() -> void:
	for notes in waterfalls_down.values():
		var pitch_notes: Array = notes
		for i in range(pitch_notes.size()):
			if is_instance_valid(pitch_notes[i]):
				pitch_notes[i].queue_free()
	waterfalls_down.clear()

func _on_playback_finished() -> void:
	_clear_down_waterfalls()

