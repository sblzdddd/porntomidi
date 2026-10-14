extends RefCounted
class_name RealtimeChannelChordAnalyzer

const TargetChannelNoteOverlapScript = preload("res://scripts/utils/target_channel_note_overlap.gd")

signal chord_changed(chord_info: Dictionary)

var target_channel: int = 7
var _overlap: RefCounted = TargetChannelNoteOverlapScript.new()
var _detector: RefCounted = ChordDetector.new()
var _last_signature: String = ""

func set_target_channel(channel: int) -> void:
	target_channel = clampi(channel, 0, 15)
	_overlap.set_target_channel(target_channel)
	_last_signature = ""

func reset() -> void:
	_overlap.clear()
	_last_signature = ""

func flush() -> Dictionary:
	_overlap.clear()
	return _detect_if_changed()

func note_on(channel: int, pitch: int, velocity: int) -> Dictionary:
	if not _overlap.note_on(channel, pitch, velocity):
		return {}
	return _detect_if_changed()

func note_off(channel: int, pitch: int) -> Dictionary:
	if not _overlap.note_off(channel, pitch):
		return {}
	return _detect_if_changed()

func _detect_if_changed() -> Dictionary:
	var overlapping_notes: Array[int] = _overlap.get_overlapping_notes()
	var chord_info: Dictionary = _detector.analyze_midi_notes(overlapping_notes)
	var signature := _build_signature(chord_info)
	if signature == _last_signature:
		return {}

	_last_signature = signature
	chord_changed.emit(chord_info)
	return chord_info

func _build_signature(chord_info: Dictionary) -> String:
	var pitch_classes: Array = chord_info.get("pitch_classes", [])
	var parts: Array[String] = []
	for pc in pitch_classes:
		parts.append(str(pc))
	return "%s|%s" % [String(chord_info.get("name", "-")), ",".join(parts)]
