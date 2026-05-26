extends RefCounted
class_name PlaybackClock


# A monotonically-increasing clock (in milliseconds) that freezes while
# MIDI playback is paused.

static var _pause_offset_ms: float = 0.0
static var _pause_start_ms: float = -1.0

static func now_ms() -> float:
	if _pause_start_ms >= 0.0:
		return _pause_start_ms - _pause_offset_ms
	return float(Time.get_ticks_msec()) - _pause_offset_ms

static func is_paused() -> bool:
	return _pause_start_ms >= 0.0

static func notify_pause() -> void:
	if _pause_start_ms >= 0.0:
		return
	_pause_start_ms = float(Time.get_ticks_msec())

static func notify_resume() -> void:
	if _pause_start_ms < 0.0:
		return
	_pause_offset_ms += float(Time.get_ticks_msec()) - _pause_start_ms
	_pause_start_ms = -1.0
	