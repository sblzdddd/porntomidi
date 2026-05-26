extends RefCounted
class_name PlaybackSpanBuilder

const NOTE_COUNT_PER_CHANNEL := 128

static func build(events: Array) -> Array:
	var spans: Array = []
	var pending_notes: Dictionary = {}

	for event_chunk in events:
		var channel: int = event_chunk.channel_number
		var event = event_chunk.event
		match event.type:
			SMF.MIDIEventType.note_on:
				var note_on_event: SMF.MIDIEventNoteOn = event as SMF.MIDIEventNoteOn
				if note_on_event.velocity > 0:
					var key := _make_key(channel, note_on_event.note)
					var span = PlaybackNoteSpan.new(channel, note_on_event.note, note_on_event.velocity, float(event_chunk.time))
					spans.append(span)
					if not pending_notes.has(key):
						pending_notes[key] = QueueState.create()
					QueueState.push(pending_notes[key], span)
				else:
					_close_pending_span(pending_notes, channel, note_on_event.note, float(event_chunk.time))
			SMF.MIDIEventType.note_off:
				var note_off_event: SMF.MIDIEventNoteOff = event as SMF.MIDIEventNoteOff
				_close_pending_span(pending_notes, channel, note_off_event.note, float(event_chunk.time))
			_:
				pass

	for queue in pending_notes.values():
		while not QueueState.is_empty(queue):
			var span = QueueState.pop(queue)
			if span != null:
				span.end_time = max(span.start_time + 1.0, span.end_time)

	return spans

static func _close_pending_span(pending_notes: Dictionary, channel: int, note: int, end_time: float) -> void:
	var key := _make_key(channel, note)
	if not pending_notes.has(key):
		return
	var queue: Dictionary = pending_notes[key]
	var span = QueueState.pop(queue)
	if span != null:
		span.end_time = max(span.start_time + 1.0, end_time)
	if QueueState.is_empty(queue):
		pending_notes.erase(key)

static func _make_key(channel: int, note: int) -> int:
	return channel * NOTE_COUNT_PER_CHANNEL + note
