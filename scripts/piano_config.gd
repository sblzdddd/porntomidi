extends Node

signal config_changed(rebuild: bool)

var start_pitch: int = 21:
	set(value):
		if start_pitch == value: return
		start_pitch = value
		config_changed.emit(true)

var keys_count: int = 88:
	set(value):
		if keys_count == value: return
		keys_count = value
		config_changed.emit(true)

var waterfall_speed: float = 6.0:
	set(value):
		if waterfall_speed == value: return
		waterfall_speed = value
		config_changed.emit(false)

var waterfall_bottom: float = 0.0:
	set(value):
		if waterfall_bottom == value: return
		waterfall_bottom = value
		config_changed.emit(false)

var key_coords: Array[Vector2] = []:
	set(value):
		if key_coords == value: return
		key_coords = value
		config_changed.emit(false)

var instrument_palette: Array[Color] = [
	Color("fd615eff"),
	Color("fb8d5aff"),
	Color("f5c141ff"),
	Color("62b400ff"),
	Color("00c09bff"),
	Color("009ffeff"),
	Color("b17effff")
]:
	set(value):
		if instrument_palette == value: return
		instrument_palette = value
		config_changed.emit(false)

var play_particle_max_count: int = 88:
	set(value):
		value = max(value, 0)
		if play_particle_max_count == value: return
		play_particle_max_count = value
		config_changed.emit(false)

func in_range(pitch: int) -> bool:
	return pitch >= start_pitch and pitch < start_pitch + keys_count
