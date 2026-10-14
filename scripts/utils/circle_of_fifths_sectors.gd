extends RefCounted
class_name CircleOfFifthsSectors

const ChordNameFormatterScript = preload("res://scripts/utils/chord_name_formatter.gd")

# Outer ring: C G D A E B Gb Db Ab Eb Bb F
const MAJOR_PITCH_CLASSES: Array[int] = [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5]
# Inner ring: Am Em Bm F#m C#m G#m Ebm Bbm Fm Cm Gm Dm
const MINOR_PITCH_CLASSES: Array[int] = [9, 4, 11, 6, 1, 8, 3, 10, 5, 0, 7, 2]

static func mask_for_chord(chord_info: Dictionary) -> int:
	var chord_name := String(chord_info.get("name", "-"))
	if chord_name.is_empty() or chord_name == "-":
		return 0

	var root_pc := int(chord_info.get("root_pitch_class", -1))
	if root_pc < 0:
		root_pc = _pitch_class_from_name(chord_name)
	if root_pc < 0:
		return 0

	var sector_index := sector_index_for_pitch(root_pc, _is_minor_chord(chord_name))
	if sector_index < 0:
		return 0
	return 1 << sector_index

static func sector_index_for_pitch(pitch_class: int, is_minor: bool) -> int:
	var order: Array[int] = MINOR_PITCH_CLASSES if is_minor else MAJOR_PITCH_CLASSES
	var index := order.find(posmod(pitch_class, 12))
	if index < 0:
		return -1
	return index + (12 if is_minor else 0)

static func _is_minor_chord(chord_name: String) -> bool:
	var suffix: String = ChordNameFormatterScript.split_root_and_suffix(chord_name).suffix
	if suffix.is_empty():
		return false
	if suffix.begins_with("maj"):
		return false
	return suffix.begins_with("m") or suffix.begins_with("dim")

static func _pitch_class_from_name(chord_name: String) -> int:
	var root: String = ChordNameFormatterScript.split_root_and_suffix(chord_name).root
	if root.is_empty() or root == "-":
		return -1
	var names := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	var flat_names := {"Db": 1, "Eb": 3, "Gb": 6, "Ab": 8, "Bb": 10}
	if flat_names.has(root):
		return int(flat_names[root])
	var index := names.find(root)
	return index if index >= 0 else -1
