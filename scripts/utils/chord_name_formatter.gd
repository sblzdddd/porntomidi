extends RefCounted
class_name ChordNameFormatter

const ROOT_CHARS := "ABCDEFG"

static func to_bbcode(
	chord_name: String,
	base_font_size: int = 30,
	notation_font_size: int = 18,
	color: String = "#aaa"
) -> String:
	if chord_name.is_empty():
		chord_name = "-"
	var parts := split_root_and_suffix(chord_name)
	return (
		_styled(parts.root, base_font_size, color)
		+ _styled(parts.suffix, notation_font_size, color)
	)

static func split_root_and_suffix(chord_name: String) -> Dictionary:
	if chord_name.is_empty() or chord_name == "-":
		return {"root": "-", "suffix": ""}
	if chord_name[0] not in ROOT_CHARS:
		return {"root": chord_name, "suffix": ""}

	var end := 1
	if end < chord_name.length() and chord_name[end] in "#b":
		end += 1
	return {
		"root": chord_name.substr(0, end),
		"suffix": chord_name.substr(end),
	}

static func _styled(text: String, font_size: int, color: String) -> String:
	if text.is_empty():
		return ""
	return "[font_size=%d][color=%s]%s[/color][/font_size]" % [font_size, color, text]
