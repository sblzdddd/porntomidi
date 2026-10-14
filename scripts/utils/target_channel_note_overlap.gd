extends RefCounted
class_name TargetChannelNoteOverlap

const DRUM_CHANNEL := 9

var target_channel: int = 7
var _held_pitches: Dictionary = {}

func set_target_channel(channel: int) -> void:
	target_channel = clampi(channel, 0, 15)
	clear()

func is_drum_channel(channel: int) -> bool:
	return channel == DRUM_CHANNEL

func applies_to_channel(channel: int) -> bool:
	return channel == target_channel and not is_drum_channel(channel)

func note_on(channel: int, pitch: int, velocity: int) -> bool:
	if not applies_to_channel(channel):
		return false
	if velocity <= 0:
		return note_off(channel, pitch)
	_held_pitches[pitch] = int(_held_pitches.get(pitch, 0)) + 1
	return true

func note_off(channel: int, pitch: int) -> bool:
	if not applies_to_channel(channel):
		return false
	if not _held_pitches.has(pitch):
		return false
	var count := int(_held_pitches[pitch]) - 1
	if count <= 0:
		_held_pitches.erase(pitch)
	else:
		_held_pitches[pitch] = count
	return true

func get_overlapping_notes() -> Array[int]:
	var notes: Array[int] = []
	for pitch in _held_pitches.keys():
		notes.append(int(pitch))
	notes.sort()
	return notes

func clear() -> void:
	_held_pitches.clear()
