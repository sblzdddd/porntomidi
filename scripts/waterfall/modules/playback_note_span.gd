extends RefCounted
class_name PlaybackNoteSpan

var channel: int
var note: int
var velocity: int
var start_time: float
var end_time: float

func _init(set_channel: int, set_note: int, set_velocity: int, set_start_time: float) -> void:
	channel = set_channel
	note = set_note
	velocity = set_velocity
	start_time = set_start_time
	end_time = set_start_time
