extends Node

# Define your global signals here
signal midi_input(event: InputEventMIDI)
signal note_on(pitch: int, velocity: int)
signal note_off(pitch: int)
signal control_change(id: int, value: int)
signal note_on_channel(channel: int, pitch: int, velocity: int)
signal note_off_channel(channel: int, pitch: int)
signal control_change_channel(channel: int, id: int, value: int)
signal program_change(channel: int, instrument: int)
signal pitch_bend(channel: int, value: int)

func _ready():
	OS.open_midi_inputs()
	print(OS.get_connected_midi_inputs())

func _input(input_event):
	if input_event is InputEventMIDI:
		_print_midi_info(input_event)

func _print_midi_info(midi_event: InputEventMIDI):
	midi_input.emit(midi_event)
	print(midi_event)
	# print("Channel ", midi_event.channel)
	# print("Message ", midi_event.message)
	#print("Pitch ", midi_event.pitch)
	#print("Velocity ", midi_event.velocity)
	#print("Instrument ", midi_event.instrument)
	#print("Pressure ", midi_event.pressure)
	#print("Controller number: ", midi_event.controller_number)
	#print("Controller value: ", midi_event.controller_value)
	
	if midi_event.message == MIDI_MESSAGE_NOTE_ON and midi_event.velocity > 0:
		MidiEvents.note_on.emit(midi_event.pitch, midi_event.velocity)
		MidiEvents.note_on_channel.emit(midi_event.channel, midi_event.pitch, midi_event.velocity)
	elif midi_event.message == MIDI_MESSAGE_NOTE_OFF or (midi_event.message == MIDI_MESSAGE_NOTE_ON and midi_event.velocity == 0):
		note_off.emit(midi_event.pitch)
		note_off_channel.emit(midi_event.channel, midi_event.pitch)
	elif midi_event.message == MIDI_MESSAGE_CONTROL_CHANGE:
		control_change.emit(midi_event.controller_number, midi_event.controller_value)
		control_change_channel.emit(midi_event.channel, midi_event.controller_number, midi_event.controller_value)
	elif midi_event.message == MIDI_MESSAGE_PROGRAM_CHANGE:
		program_change.emit(midi_event.channel, midi_event.instrument)
	elif midi_event.message == MIDI_MESSAGE_PITCH_BEND:
		pitch_bend.emit(midi_event.channel, midi_event.pitch)
	
