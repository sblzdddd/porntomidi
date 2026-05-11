extends Button
class_name KeyButton

@export var label: RichTextLabel
var pitch: int = 0
var is_black: bool = false
var _suppress_emit: bool = false
var _base_pressed_style: StyleBoxFlat = null
var _active_pressed_style: StyleBoxFlat = null

func init(set_pitch: int, set_is_black: bool) -> void:
	is_black = set_is_black
	pitch = set_pitch

func _ready() -> void:
	_make_active_style_unique()

func set_label_text(value):
	label.text = value

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			button_pressed = false

func _on_mouse_entered() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		button_pressed = true
		MidiEvents.note_on.emit(pitch, 127)
		MidiEvents.note_on_channel.emit(-1, pitch, 127)

func _on_mouse_exited() -> void:
	button_pressed = false
	MidiEvents.note_off.emit(pitch)
	MidiEvents.note_off_channel.emit(-1, pitch)

func _on_button_up() -> void:
	button_pressed = false
	MidiEvents.note_off.emit(pitch)
	MidiEvents.note_off_channel.emit(-1, pitch)
	
func midi_set(active: bool, tint: Color = Color(0, 0, 0, 0)):
	_suppress_emit = true
	set_pressed_no_signal(active)
	_suppress_emit = false
	_apply_pressed_tint(active, tint)


func _on_pressed() -> void:
	if _suppress_emit:
		return
	MidiEvents.note_on.emit(pitch, 127)
	MidiEvents.note_on_channel.emit(-1, pitch, 127)

func _make_active_style_unique() -> void:
	var pressed_style := get_theme_stylebox("pressed")
	if not (pressed_style is StyleBoxFlat):
		return
	_base_pressed_style = (pressed_style as StyleBoxFlat).duplicate()
	_active_pressed_style = _base_pressed_style.duplicate()
	add_theme_stylebox_override("pressed", _active_pressed_style)

func _apply_pressed_tint(active: bool, tint: Color) -> void:
	if _active_pressed_style == null or _base_pressed_style == null:
		return
	if active and tint.a > 0.0:
		_active_pressed_style.bg_color = Color(tint.r, tint.g, tint.b, 1) * 1.5
		var border_tint := tint.lightened(0.25) * 1.5
		_active_pressed_style.border_color = Color(border_tint.r, border_tint.g, border_tint.b, 1)
	else:
		_active_pressed_style.bg_color = _base_pressed_style.bg_color
		_active_pressed_style.border_color = _base_pressed_style.border_color
