extends Control

const NOTE_PREFAB = preload("res://prefabs/note.tscn")

var waterfalls_up: Dictionary[int, Dictionary] = {}

func _ready():
	MidiEvents.note_on_channel.connect(on_note_on_channel)
	MidiEvents.note_off_channel.connect(on_note_off_channel)

func on_note_on_channel(channel: int, pitch: int, _velocity: int):
	if not PianoConfig.in_range(pitch):
		return
	var note: Note = NOTE_PREFAB.instantiate()
	add_child(note)
	note.init(pitch, false, channel)
	note.apply_tint(ChannelColorAllocator.get_color(channel))
	var pitch_queue: Dictionary = _get_or_create_pitch_queue(pitch)
	QueueState.push(pitch_queue, note)

func on_note_off_channel(_channel: int, pitch: int):
	if not (PianoConfig.in_range(pitch) and waterfalls_up.has(pitch)):
		return
	var pitch_notes: Dictionary = waterfalls_up[pitch]
	var note: Note = _pop_valid_note(pitch_notes)
	if note != null:
		note.end_note()
	if QueueState.is_empty(pitch_notes):
		waterfalls_up.erase(pitch)

func _pop_valid_note(queue: Dictionary) -> Note:
	while not QueueState.is_empty(queue):
		var note = QueueState.pop(queue) as Note
		if is_instance_valid(note):
			return note
	return null

func _get_or_create_pitch_queue(pitch: int) -> Dictionary:
	if not waterfalls_up.has(pitch):
		waterfalls_up[pitch] = QueueState.create()
	return waterfalls_up[pitch]
