extends RefCounted
class_name ChordDetector

const ChordPatternsData = preload("res://scripts/utils/chord_patterns.gd")
const NOTE_NAMES_SHARP := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

func analyze_midi_notes(midi_notes: Array[int]) -> Dictionary:
	if midi_notes.is_empty():
		return {
			"name": "-",
			"root_pitch_class": -1,
			"bass_pitch_class": -1,
			"pitch_classes": [],
		}

	var sorted_notes := midi_notes.duplicate()
	sorted_notes.sort()

	if sorted_notes.size() == 1:
		var single_pc := posmod(sorted_notes[0], 12)
		return {
			"name": NOTE_NAMES_SHARP[single_pc],
			"root_pitch_class": single_pc,
			"bass_pitch_class": single_pc,
			"pitch_classes": [single_pc],
		}

	var pitch_classes := _unique_pitch_classes(sorted_notes)
	var bass_pc := posmod(sorted_notes[0], 12)
	var root_pc := _find_root(pitch_classes, bass_pc)
	var interval_map := _get_interval_map(pitch_classes, root_pc)
	var matched_pattern := _match_pattern(interval_map)

	var chord_name: String = NOTE_NAMES_SHARP[root_pc]
	if matched_pattern.is_empty():
		chord_name += "?"
	else:
		chord_name += String(matched_pattern["suffix"])

	if bass_pc != root_pc:
		chord_name += "/" + NOTE_NAMES_SHARP[bass_pc]

	return {
		"name": chord_name,
		"root_pitch_class": root_pc,
		"bass_pitch_class": bass_pc,
		"pitch_classes": pitch_classes,
	}

func _find_root(pitch_classes: Array[int], bass_pc: int) -> int:
	if pitch_classes.is_empty():
		return -1
	if pitch_classes.size() == 1:
		return pitch_classes[0]

	var best_root := pitch_classes[0]
	var best_priority := -1
	var best_score := -99999.0

	for candidate_root in pitch_classes:
		var interval_map := _get_interval_map(pitch_classes, candidate_root)
		for pattern in ChordPatternsData.PATTERNS:
			if not _pattern_matches(interval_map, pattern):
				continue
			var score := float(pattern["priority"])
			if bass_pc == candidate_root:
				score += 5.0
			var extra_notes := interval_map.size() - int(pattern["intervals"].size())
			score -= float(extra_notes) * 0.5
			if score > best_score or (is_equal_approx(score, best_score) and int(pattern["priority"]) > best_priority):
				best_score = score
				best_priority = int(pattern["priority"])
				best_root = candidate_root

	return best_root

func _get_interval_map(pitch_classes: Array[int], root_pc: int) -> Dictionary:
	var interval_map := {0: true}
	for pitch_class in pitch_classes:
		var interval := posmod(pitch_class - root_pc, 12)
		interval_map[interval] = true
		if interval == 2:
			interval_map[14] = true
		elif interval == 5:
			interval_map[17] = true
		elif interval == 9:
			interval_map[21] = true
	return interval_map

func _match_pattern(interval_map: Dictionary) -> Dictionary:
	var best_pattern := {}
	var best_priority := -1
	var best_size := -1

	for pattern in ChordPatternsData.PATTERNS:
		if not _pattern_matches(interval_map, pattern):
			continue
		var priority := int(pattern["priority"])
		var size := int(pattern["intervals"].size())
		if priority > best_priority or (priority == best_priority and size > best_size):
			best_pattern = pattern
			best_priority = priority
			best_size = size

	return best_pattern

func _pattern_matches(interval_map: Dictionary, pattern: Dictionary) -> bool:
	for interval in pattern["intervals"]:
		if not interval_map.has(interval):
			return false
	return true

func _unique_pitch_classes(midi_notes: Array[int]) -> Array[int]:
	var map := {}
	for midi_note in midi_notes:
		map[posmod(midi_note, 12)] = true
	var unique: Array[int] = []
	for pitch_class in map.keys():
		unique.append(int(pitch_class))
	unique.sort()
	return unique
