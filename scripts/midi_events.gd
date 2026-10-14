extends Node

signal midi_input(event: InputEventMIDI)
signal control_change(id: int, value: int)
signal note_on_channel(channel: int, pitch: int, velocity: int)
signal note_off_channel(channel: int, pitch: int)
signal control_change_channel(channel: int, id: int, value: int)
signal program_change(channel: int, instrument: int)
signal pitch_bend(channel: int, value: int)
@warning_ignore("unused_signal")
signal playback_seeked(position: float)
@warning_ignore("unused_signal")
signal playback_paused
@warning_ignore("unused_signal")
signal midi_file_loaded(path: String)
signal chord_detected(chord_info: Dictionary)

@export_range(0, 15) var chord_analysis_channel: int = 6
@export var print_raw_midi_events: bool = false

var _chord_analyzer := RealtimeChannelChordAnalyzer.new()
var _midi_player: MidiPlayer = null

func _ready():
	OS.open_midi_inputs()
	print(OS.get_connected_midi_inputs())
	_chord_analyzer.set_target_channel(chord_analysis_channel)
	playback_seeked.connect(_on_playback_seeked)
	playback_paused.connect(_on_playback_paused)
	call_deferred("_connect_midi_player")

func _input(input_event):
	if input_event is InputEventMIDI:
		_print_midi_info(input_event)

func _print_midi_info(midi_event: InputEventMIDI):
	midi_input.emit(midi_event)
	if print_raw_midi_events:
		print(midi_event)

	if midi_event.message == MIDI_MESSAGE_NOTE_ON and midi_event.velocity > 0:
		note_on_channel.emit(midi_event.channel, midi_event.pitch, midi_event.velocity)
		_track_note_on(midi_event.channel, midi_event.pitch, midi_event.velocity)
	elif midi_event.message == MIDI_MESSAGE_NOTE_OFF or (midi_event.message == MIDI_MESSAGE_NOTE_ON and midi_event.velocity == 0):
		note_off_channel.emit(midi_event.channel, midi_event.pitch)
		_track_note_off(midi_event.channel, midi_event.pitch)
	elif midi_event.message == MIDI_MESSAGE_CONTROL_CHANGE:
		control_change.emit(midi_event.controller_number, midi_event.controller_value)
		control_change_channel.emit(midi_event.channel, midi_event.controller_number, midi_event.controller_value)
	elif midi_event.message == MIDI_MESSAGE_PROGRAM_CHANGE:
		program_change.emit(midi_event.channel, midi_event.instrument)
	elif midi_event.message == MIDI_MESSAGE_PITCH_BEND:
		pitch_bend.emit(midi_event.channel, midi_event.pitch)

func _connect_midi_player() -> void:
	_midi_player = get_tree().root.find_child("MidiPlayer", true, false) as MidiPlayer
	if _midi_player == null:
		push_warning("MidiEvents: MidiPlayer not found; playback chord analysis disabled")
		return
	_midi_player.playback_note_on.connect(_track_note_on)
	_midi_player.playback_note_off.connect(_track_note_off)
	_midi_player.finished.connect(_flush_chord_analyzer)

func _track_note_on(channel: int, pitch: int, velocity: int) -> void:
	_report_chord_change(_chord_analyzer.note_on(channel, pitch, velocity))

func _track_note_off(channel: int, pitch: int) -> void:
	_report_chord_change(_chord_analyzer.note_off(channel, pitch))

func _flush_chord_analyzer() -> void:
	_report_chord_change(_chord_analyzer.flush())

func _on_playback_seeked(_position: float) -> void:
	_flush_chord_analyzer()

func _on_playback_paused() -> void:
	_flush_chord_analyzer()

func _report_chord_change(chord_info: Dictionary) -> void:
	if chord_info.is_empty():
		return
	chord_detected.emit(chord_info)
	var channel_label := chord_analysis_channel + 1
	print("[Chord][Ch %d] %s" % [channel_label, String(chord_info.get("name", "-"))])
