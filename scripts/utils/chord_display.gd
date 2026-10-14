extends Control
class_name ChordDisplay

const ChordNameFormatterScript = preload("res://scripts/utils/chord_name_formatter.gd")
const CircleOfFifthsSectorsScript = preload("res://scripts/utils/circle_of_fifths_sectors.gd")

@export var chord_label_path: NodePath
@export var circle_of_fifths_path: NodePath
@export var base_font_size: int = 30
@export var notation_font_size: int = 18
@export var text_color: String = "#aaa"
@export var empty_display: String = "-"

var _label: RichTextLabel = null
var _circle_material: ShaderMaterial = null

func _ready() -> void:
	_label = get_node_or_null(chord_label_path) as RichTextLabel
	if _label == null:
		push_warning("ChordDisplay: RichTextLabel not found at %s" % chord_label_path)
	else:
		_label.bbcode_enabled = true
		_label.fit_content = true

	_setup_circle_of_fifths()
	set_chord_name(empty_display)
	MidiEvents.chord_detected.connect(_on_chord_detected)

func _setup_circle_of_fifths() -> void:
	var circle := get_node_or_null(circle_of_fifths_path) as ColorRect
	if circle == null:
		return
	var shader_mat := circle.material as ShaderMaterial
	if shader_mat == null:
		push_warning("ChordDisplay: CircleOfFifths has no ShaderMaterial")
		return
	_circle_material = shader_mat.duplicate() as ShaderMaterial
	circle.material = _circle_material
	_set_sector_mask(0)

func _exit_tree() -> void:
	if MidiEvents.chord_detected.is_connected(_on_chord_detected):
		MidiEvents.chord_detected.disconnect(_on_chord_detected)

func _on_chord_detected(chord_info: Dictionary) -> void:
	set_chord_name(String(chord_info.get("name", empty_display)))
	_set_sector_mask(CircleOfFifthsSectorsScript.mask_for_chord(chord_info))

func set_chord_name(chord_name: String) -> void:
	if _label == null:
		return
	_label.text = ChordNameFormatterScript.to_bbcode(
		chord_name,
		base_font_size,
		notation_font_size,
		text_color
	)

func _set_sector_mask(mask: int) -> void:
	if _circle_material == null:
		return
	_circle_material.set_shader_parameter("sector_mask", mask)
