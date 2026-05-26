extends Label

@export var waterfall_root_path: NodePath = NodePath("../../../ViewRoot/WaterfallRoot/PlaybackPool")
@export var poll_interval_sec: float = 0.1

var _waterfall_root: Node = null
var _poll_elapsed_sec: float = 0.0

func _ready() -> void:
	_waterfall_root = get_node_or_null(waterfall_root_path)
	set_process(true)

func _process(delta: float) -> void:
	_poll_elapsed_sec += delta
	if _poll_elapsed_sec < poll_interval_sec:
		return
	_poll_elapsed_sec = 0.0

	var fps := Engine.get_frames_per_second()
	# text = "FPS: %d" % fps

	if _waterfall_root == null: return
	var pool_status: Dictionary = _waterfall_root.call("get_status")
	text = "FPS: %d\nPool A:%d O:%d F:%d PF:%d\nMIDI E:%d P:%d R:%d T:%.1f %s" % [
		fps,
		int(pool_status.get("active", 0)),
		int(pool_status.get("orphan", 0)),
		int(pool_status.get("freed", 0)),
		int(pool_status.get("physically_freed", 0)),
		int(pool_status.get("events_total", 0)),
		int(pool_status.get("event_pointer", 0)),
		int(pool_status.get("remaining", 0)),
		float(pool_status.get("position", 0.0)),
		"PLAY" if bool(pool_status.get("playing", false)) else "STOP"
	]
