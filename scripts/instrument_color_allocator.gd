extends RefCounted
class_name InstrumentColorAllocator

static var _instrument_slots: Dictionary = {}
static var _next_slot: int = 0

static func reset() -> void:
	_instrument_slots.clear()
	_next_slot = 0

static func get_color(channel: int) -> Color:
	if channel < 0:
		return _color_for_slot(0)
	if not _instrument_slots.has(channel):
		_instrument_slots[channel] = _next_slot
		_next_slot += 1
	return _color_for_slot(int(_instrument_slots[channel]))

static func _color_for_slot(slot: int) -> Color:
	var palette: Array[Color] = PianoConfig.instrument_palette
	if palette.is_empty():
		return Color.WHITE

	var palette_size := palette.size()
	var palette_index := posmod(slot, palette_size)
	var wrap_count := int(floor(float(slot) / float(palette_size)))
	var base_color: Color = palette[palette_index]
	if wrap_count <= 0:
		return base_color

	var darken_step: float = 0.18
	var darken_amount: float = min(0.85, float(wrap_count) * darken_step)
	return base_color.darkened(darken_amount)
