extends Button

@export var midi_player: MidiPlayer = null
@export var file_dialog: FileDialog = null
@export var auto_play: bool = true

var _was_playing_before_dialog: bool = false
var _paused_position_before_dialog: float = 0.0

func _ready() -> void:
	_configure_dialog()
	pressed.connect(_on_pressed)
	if file_dialog != null:
		file_dialog.file_selected.connect(_on_file_selected)
		file_dialog.canceled.connect(_on_dialog_canceled)
		file_dialog.visibility_changed.connect(_on_dialog_visibility_changed)

func _configure_dialog() -> void:
	if file_dialog == null:
		return
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.mid, *.midi ; MIDI Files"])
	file_dialog.title = "Open MIDI File"
	file_dialog.use_native_dialog = true

func _on_pressed() -> void:
	if file_dialog == null:
		push_warning("OpenMidiFile: no FileDialog assigned")
		return
	_pause_for_dialog()
	file_dialog.popup_centered_ratio(0.6)

func _pause_for_dialog() -> void:
	if midi_player == null:
		return
	_was_playing_before_dialog = midi_player.playing
	_paused_position_before_dialog = midi_player.position
	if midi_player.playing:
		midi_player.stop()

func _resume_after_dialog() -> void:
	if midi_player == null or not _was_playing_before_dialog:
		_clear_pause_state()
		return
	midi_player.play(maxf(0.0, _paused_position_before_dialog))
	_clear_pause_state()

func _clear_pause_state() -> void:
	_was_playing_before_dialog = false
	_paused_position_before_dialog = 0.0

func _on_dialog_canceled() -> void:
	_resume_after_dialog()

func _on_dialog_visibility_changed() -> void:
	# Native dialogs emit `canceled` reliably, but custom dialogs only
	# emit it when the user clicks Cancel; closing via Esc or the window
	# X just hides them. This guarantees we always resume in those cases.
	if file_dialog == null or file_dialog.visible:
		return
	if not _was_playing_before_dialog and _paused_position_before_dialog == 0.0:
		return
	_resume_after_dialog()

func _on_file_selected(path: String) -> void:
	if midi_player == null:
		push_warning("OpenMidiFile: no MidiPlayer assigned")
		_clear_pause_state()
		return
	if path.is_empty():
		_resume_after_dialog()
		return
	_clear_pause_state()
	midi_player.stop()
	midi_player.set_file(path)
	MidiEvents.midi_file_loaded.emit(path)
	if auto_play:
		midi_player.play(0.0)
