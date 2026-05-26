extends Control

const NOTE_PREFAB = preload("res://prefabs/note.tscn")

# How many screen-heights ahead of the playhead we want notes pre-spawned.
# Notes travel at `waterfall_speed / 4` pixels per millisecond (see note.gd),
# so the look-ahead window in ms is `waterfall_bottom / (waterfall_speed / 4)`.
const _LOOKAHEAD_HEIGHTS := 1.0

var active_down_notes: Dictionary = {}
var midi_player: MidiPlayer = null

var playback_note_spans: Array = []
var playback_spawn_index: int = 0
var playback_last_position: float = -1.0
var playback_cached_events: Array = []
var playback_cached_smf = null
var _notify_config_pending := false
var _recycle_note_callback: Callable = Callable()
var _was_playing: bool = false

func _ready() -> void:
	MidiEvents.control_change.connect(resize)
	MidiEvents.playback_seeked.connect(_on_playback_seeked)
	midi_player = get_node_or_null("../../../MidiPlayer")
	if midi_player != null:
		midi_player.finished.connect(_on_playback_finished)
		_rebuild_playback_cache()
	_recycle_note_callback = Callable(self, "_on_note_recycled")
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
	PianoConfig.waterfall_bottom = get_transform().get_origin().y + size.y

func _process(_delta: float) -> void:
	if midi_player == null: return
	_sync_playback_clock_state()
	if not _has_track_events() or _refresh_playback_cache_if_needed():
		return
	if not midi_player.playing:
		playback_last_position = midi_player.position
		return
	# is implicit seek
	if playback_last_position >= 0.0 and midi_player.position + 1.0 < playback_last_position:
		_resync_after_seek()
	_spawn_scheduled_playback_notes()
	playback_last_position = midi_player.position

func _has_track_events() -> bool:
	return midi_player.track_status != null and midi_player.track_status.events != null

# Returns true if a full rebuild happened this frame
func _refresh_playback_cache_if_needed() -> bool:
	if not is_same(playback_cached_smf, midi_player.smf_data):
		_rebuild_playback_cache()
		return true
	# MidiPlayer.play() re-creates track_status.events as a new array even when
	# the underlying SMF data is unchanged.
	if not is_same(playback_cached_events, midi_player.track_status.events):
		playback_cached_events = midi_player.track_status.events
	return false

func _on_note_recycled(note: Note) -> void:
	active_down_notes.erase(note.get_instance_id())
	NotePool.release(note)

func _rebuild_playback_cache() -> void:
	_clear_down_waterfalls()
	playback_note_spans.clear()
	playback_spawn_index = 0
	playback_last_position = midi_player.position if midi_player != null else -1.0
	playback_cached_events = []
	playback_cached_smf = null
	ChannelColorAllocator.reset()

	if midi_player == null or not _has_track_events():
		return

	playback_cached_smf = midi_player.smf_data
	playback_cached_events = midi_player.track_status.events
	playback_note_spans = PlaybackSpanBuilder.build(playback_cached_events)
	_resync_playback_spawn_cursor()

func _spawn_scheduled_playback_notes() -> void:
	if playback_note_spans.is_empty():
		return
	var spawn_until: float = midi_player.position + _get_lookahead_timebase()
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
	var now_ms: float = PlaybackClock.now_ms()
	var start_ms: float = now_ms + MidiTimebase.units_to_ms(midi_player, span.start_time - midi_player.position)
	var end_ms: float = now_ms + MidiTimebase.units_to_ms(midi_player, span.end_time - midi_player.position)
	var tint: Color = ChannelColorAllocator.get_color(span.channel)
	note.init_fixed_span_down(pitch, start_ms, end_ms, tint, span.channel)
	active_down_notes[note.get_instance_id()] = note

func _get_lookahead_timebase() -> float:
	var px_speed: float = max(0.001, PianoConfig.waterfall_speed)
	var lead_seconds: float = max(0.0, PianoConfig.waterfall_bottom * 4.0 * _LOOKAHEAD_HEIGHTS / (px_speed * 1000.0))
	return MidiTimebase.seconds_to_units(midi_player, lead_seconds)

func _resync_playback_spawn_cursor() -> void:
	playback_spawn_index = 0
	if playback_note_spans.is_empty() or midi_player == null:
		return
	var min_start: float = midi_player.position - _get_lookahead_timebase()
	while playback_spawn_index < playback_note_spans.size():
		if playback_note_spans[playback_spawn_index].start_time >= min_start:
			break
		playback_spawn_index += 1

func _clear_down_waterfalls() -> void:
	var notes: Array = active_down_notes.values()
	active_down_notes.clear()
	for note in notes:
		if is_instance_valid(note):
			NotePool.release(note)

func _resync_after_seek() -> void:
	_clear_down_waterfalls()
	_resync_playback_spawn_cursor()

func _on_playback_finished() -> void:
	_clear_down_waterfalls()

func _on_playback_seeked(_new_position: float) -> void:
	_resync_after_seek()
	if midi_player != null:
		playback_last_position = midi_player.position

func _sync_playback_clock_state() -> void:
	var is_playing: bool = midi_player.playing
	if is_playing == _was_playing: return
	_was_playing = is_playing
	if is_playing:
		PlaybackClock.notify_resume()
	else:
		PlaybackClock.notify_pause()
		MidiEvents.playback_paused.emit()

func _exit_tree() -> void:
	_clear_down_waterfalls()

func get_status() -> Dictionary:
	var events_total := 0
	var event_pointer := 0
	if midi_player != null and _has_track_events():
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
		"position": midi_player.position if midi_player != null else 0.0,
		"playing": midi_player != null and midi_player.playing
	}
