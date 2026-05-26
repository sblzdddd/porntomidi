extends Control

@onready var midi_player: MidiPlayer = $MidiPlayer
@onready var progress_slider: HSlider = $MarginContainer/HBoxContainer/HBoxContainer/VBoxContainer/ProgressSlider
@onready var time_elapsed: Label = $MarginContainer/HBoxContainer/HBoxContainer/VBoxContainer/TimeDisplay/TimeElapsed
@onready var time_remaining: Label = $MarginContainer/HBoxContainer/HBoxContainer/VBoxContainer/TimeDisplay/TimeRemaining
@onready var play_pause_button: Button = $MarginContainer/HBoxContainer/HBoxContainer/HBoxContainer/PlayPause
@onready var stop_button: Button = $MarginContainer/HBoxContainer/HBoxContainer/HBoxContainer/Stop

var play_icon: Texture2D = preload("res://textures/MaterialSymbolsPlayArrowRounded.svg")
var pause_icon: Texture2D = preload("res://textures/MaterialSymbolsPause.svg")

var _is_scrubbing: bool = false
var _is_slider_connected: bool = false
var _paused_position: float = 0.0
var _duration_timebase: float = 0.0

func _ready() -> void:
	_wire_ui()
	_refresh_duration()
	_update_ui()

func _process(_delta: float) -> void:
	_refresh_duration()
	if not _is_scrubbing:
		progress_slider.set_value_no_signal(clampf(midi_player.position, 0.0, _duration_timebase))
	_update_time_labels()
	_update_button_icon()

func _wire_ui() -> void:
	if not _is_slider_connected:
		progress_slider.value_changed.connect(_on_progress_slider_value_changed)
		progress_slider.drag_started.connect(_on_progress_drag_started)
		progress_slider.drag_ended.connect(_on_progress_drag_ended)
		_is_slider_connected = true
	play_pause_button.pressed.connect(_on_play_pause_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	midi_player.finished.connect(_on_midi_finished)
	MidiEvents.midi_file_loaded.connect(_on_midi_file_loaded)

func _refresh_duration() -> void:
	_duration_timebase = maxf(_duration_timebase, midi_player.last_position)
	progress_slider.max_value = maxf(0.0, _duration_timebase)
	progress_slider.editable = _duration_timebase > 0.0

func _update_ui() -> void:
	progress_slider.set_value_no_signal(clampf(midi_player.position, 0.0, _duration_timebase))
	_update_time_labels()
	_update_button_icon()

func _update_time_labels() -> void:
	var elapsed_seconds := MidiTimebase.units_to_seconds(midi_player, midi_player.position)
	var total_seconds := MidiTimebase.units_to_seconds(midi_player, _duration_timebase)
	var remaining_seconds := maxf(0.0, total_seconds - elapsed_seconds)
	time_elapsed.text = _format_time(elapsed_seconds)
	time_remaining.text = "-%s" % _format_time(remaining_seconds)

func _update_button_icon() -> void:
	play_pause_button.icon = pause_icon if midi_player.playing else play_icon

func _on_play_pause_pressed() -> void:
	if midi_player.playing:
		_paused_position = midi_player.position
		midi_player.stop()
		return

	var resume_position := _paused_position
	if _duration_timebase > 0.0:
		resume_position = clampf(resume_position, 0.0, _duration_timebase)
	if resume_position <= 0.0:
		midi_player.play(0.0)
	else:
		midi_player.play(resume_position)
	_paused_position = 0.0

func _on_stop_pressed() -> void:
	midi_player.stop()
	_paused_position = 0.0
	midi_player.position = 0.0
	if midi_player.track_status != null:
		midi_player.track_status.event_pointer = 0
	MidiEvents.playback_seeked.emit(0.0)
	_update_ui()

func _on_progress_drag_started() -> void:
	_is_scrubbing = true

func _on_progress_drag_ended(value_changed: bool) -> void:
	_is_scrubbing = false
	if not value_changed:
		return
	_seek_to(progress_slider.value)

func _on_progress_slider_value_changed(value: float) -> void:
	if _is_scrubbing:
		var elapsed_seconds := MidiTimebase.units_to_seconds(midi_player, value)
		var total_seconds := MidiTimebase.units_to_seconds(midi_player, _duration_timebase)
		time_elapsed.text = _format_time(elapsed_seconds)
		time_remaining.text = "-%s" % _format_time(maxf(0.0, total_seconds - elapsed_seconds))
		return
	_seek_to(value)

func _seek_to(target_timebase: float) -> void:
	if midi_player.track_status == null or midi_player.track_status.events == null or midi_player.track_status.events.is_empty():
		return
	var clamped_timebase := clampf(target_timebase, 0.0, _duration_timebase)
	midi_player.seek(clamped_timebase)
	_paused_position = clamped_timebase
	MidiEvents.playback_seeked.emit(clamped_timebase)

func _on_midi_finished() -> void:
	_paused_position = 0.0
	progress_slider.value = progress_slider.max_value
	_update_time_labels()
	_update_button_icon()

func _on_midi_file_loaded(_path: String) -> void:
	_is_scrubbing = false
	_paused_position = 0.0
	_duration_timebase = 0.0
	progress_slider.set_value_no_signal(0.0)
	_refresh_duration()
	_update_ui()

func _format_time(seconds: float) -> String:
	var total := maxi(0, int(round(seconds)))
	var mins := int(total / 60.0)
	var secs := total % 60
	return "%d:%02d" % [mins, secs]
