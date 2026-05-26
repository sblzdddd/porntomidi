extends RefCounted
class_name MidiTimebase

# Conversion helpers between MidiPlayer "timebase units" and real time.
# Centralises the `timebase * seconds_to_timebase * play_speed` factor so
# callers don't have to repeat the null guard / division-by-zero ceremony.

const _MIN_UNITS_PER_SECOND := 0.0001

static func units_per_second(midi_player: MidiPlayer) -> float:
	if midi_player == null or midi_player.smf_data == null:
		return 0.0
	return float(midi_player.smf_data.timebase) * midi_player.seconds_to_timebase * midi_player.play_speed

static func units_to_seconds(midi_player: MidiPlayer, units: float) -> float:
	var ups := units_per_second(midi_player)
	if ups <= _MIN_UNITS_PER_SECOND:
		return 0.0
	return units / ups

static func units_to_ms(midi_player: MidiPlayer, units: float) -> float:
	return units_to_seconds(midi_player, units) * 1000.0

static func seconds_to_units(midi_player: MidiPlayer, seconds: float) -> float:
	return seconds * units_per_second(midi_player)
