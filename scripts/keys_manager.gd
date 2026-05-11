extends Control

const KEY_NODE = preload("res://prefabs/key.tscn")
const BK_THEME = preload("res://themes/bk_theme.tres")
const INSTRUMENT_COLOR_ALLOCATOR = preload("res://scripts/instrument_color_allocator.gd")
const BLACK_SEMITONES = [1, 3, 6, 8, 10]

@export var white_keys_root: HBoxContainer
@export var black_keys_root: HBoxContainer
@export var box_styles: Array[StyleBoxFlat]
@export var keys: Array[KeyButton] = []
var key_coords: Array[Vector2] = []
var midi_player: MidiPlayer = null
var key_active_channels: Dictionary = {}

func _ready() -> void:
	rebuild(true)
	#get_window().size_changed.connect(_update_separation) 
	get_window().size_changed.connect(calculate_key_coords)
	PianoConfig.config_changed.connect(rebuild)
	MidiEvents.note_on_channel.connect(on_note_on_channel)
	MidiEvents.note_off_channel.connect(on_note_off_channel)
	midi_player = get_node_or_null("../../MidiPlayer")
	if midi_player != null:
		midi_player.playback_note_on.connect(on_playback_note_on)
		midi_player.playback_note_off.connect(on_playback_note_off)

func rebuild(force: bool) -> void:
	if !force: return
	keys.clear()
	key_coords.clear()
	key_active_channels.clear()
	INSTRUMENT_COLOR_ALLOCATOR.reset()
	for child in white_keys_root.get_children(): child.queue_free()
	for child in black_keys_root.get_children(): child.queue_free()
	place_keys()
	# wait for the keys to be placed
	await get_tree().process_frame
	#_update_separation()
	calculate_key_coords()

func _update_separation():
	var width = get_window().size.x
	white_keys_root.add_theme_constant_override("separation", width * 0.001)
	black_keys_root.add_theme_constant_override("separation", max(width * 0.007, 5))
	for style in box_styles:
		style.border_width_bottom = min(width * 0.005, 10)
		style.set_corner_radius_all(width * 0.002)

func add_spacer(spacing: float = 1.0):
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = spacing
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black_keys_root.add_child(spacer)

func place_keys():
	add_spacer(0.5)
	for i in PianoConfig.keys_count:
		var midi := i + PianoConfig.start_pitch
		var semitone := midi % 12
		var key: KeyButton = KEY_NODE.instantiate()
		key.init(midi, semitone in BLACK_SEMITONES)
		keys.append(key)
		if semitone in BLACK_SEMITONES: # is a Black key
			key.theme = BK_THEME
			black_keys_root.add_child(key)
			if semitone == 3 or semitone == 10: add_spacer()
		else:
			if semitone == 0: # add label for C key
				@warning_ignore("integer_division")
				key.set_label_text("[color=000]C[font_size=10]%s" % (midi / 12 - 1))
			white_keys_root.add_child(key)
	add_spacer(0.4)

func calculate_key_coords():
	key_coords = []
	for i in keys.size():
		var key := keys[i]
		var key_size := key.size.x
		var kx := key.get_transform().get_origin().x
		key_coords.append(Vector2(kx, key_size))
	PianoConfig.key_coords = key_coords

func on_note_on_channel(channel: int, pitch: int, _velocity: int):
	_set_key_active_for_channel(pitch, true, channel)

func on_note_off_channel(_channel: int, pitch: int):
	_set_key_active_for_channel(pitch, false)

func on_playback_note_on(channel: int, pitch: int, _velocity: int):
	_set_key_active_for_channel(pitch, true, channel)

func on_playback_note_off(_channel: int, pitch: int):
	_set_key_active_for_channel(pitch, false)

func _set_key_active_for_channel(pitch: int, active: bool, channel: int = -1) -> void:
	if not PianoConfig.in_range(pitch):
		return
	var active_channels: Array[int] = []
	if key_active_channels.has(pitch):
		active_channels = key_active_channels[pitch]
	if active:
		active_channels.append(channel)
	else:
		if active_channels.size() > 0:
			active_channels.pop_back()
	if active_channels.is_empty():
		key_active_channels.erase(pitch)
		keys[pitch - PianoConfig.start_pitch].midi_set(false)
	else:
		key_active_channels[pitch] = active_channels
		var tint: Color = INSTRUMENT_COLOR_ALLOCATOR.get_color(active_channels[active_channels.size() - 1])
		keys[pitch - PianoConfig.start_pitch].midi_set(true, tint)
