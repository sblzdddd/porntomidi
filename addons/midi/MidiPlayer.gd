##
##	100% pure GDScript MIDI Player [Godot MIDI Player] by あるる（きのもと 結衣） @arlez80
##
##	MIT License
##

@icon("icon.png")
class_name MidiPlayer

extends Node

# -----------------------------------------------------------------------------
# Import
const ADSR = preload( "ADSR.tscn" )
const GodotMIDIPlayerChannelAudioEffect = preload( "player/GodotMIDIPlayerChannelAudioEffect.gd" )
const GodotMIDIPlayerSysEx = preload( "player/GodotMIDIPlayerSysEx.gd" )
const GodotMIDIPlayerTrackStatus = preload( "player/GodotMIDIPlayerTrackStatus.gd" )
const GodotMIDIPlayerChannelStatus = preload( "player/GodotMIDIPlayerChannelStatus.gd" )

# -------------------------------------------------------
# Constants

## Maximum number of tracks
const max_track:int = 16
## Maximum number of channels
const max_channel:int = 16
## Maximum note number
const max_note_number:int = 128
## Maximum program number
const max_program_number:int = 128
## Drum track channel number
const drum_track_channel:int = 0x09

## MIDI Master Bus Name
const midi_master_bus_name:String = "arlez80_GMP_MASTER_BUS"
## MIDI Channnel Bus Name
const midi_channel_bus_name:String = "arlez80_GMP_CHANNEL_BUS%d"
## MIDI Channnel Bus Name Left
const midi_channel_bus_name_left:String = "arlez80_GMP_CHANNEL_BUS%d_L"
## MIDI Channnel Bus Name Right
const midi_channel_bus_name_right:String = "arlez80_GMP_CHANNEL_BUS%d_R"

# -----------------------------------------------------------------------------
# Export

## Maximum polyphony
@export_range (0, 256) var max_polyphony:int = 96 : set = set_max_polyphony
## File
@export_file ("*.mid") var file:String = "" : set = set_file
## Is playing?
@export var playing:bool = false
## Playback speed
@export_range (0.0, 100.0) var play_speed:float = 1.0
## Volume
@export_range (-80.0, 0.0) var volume_db:float = -20.0 : set = set_volume_db
## Key shift
@export var key_shift:int = 0
## Loop flag
@export var loop:bool = false
## Loop start position
@export var loop_start:float = 0.0
## Load all voices from soundfont?
@export var load_all_voices_from_soundfont:bool = true
## Soundfont
@export_file ("*.sf2") var soundfont:String = "" : set = set_soundfont
## Mix target
@export var mix_target:AudioStreamPlayer.MixTarget = AudioStreamPlayer.MIX_TARGET_STEREO
## Output bus
@export var bus:StringName = &"Master"
## NodePath that receives MIDI input events (e.g. /root/MidiEvents)
@export var midi_events_node_path:NodePath
## Enable integration with external MIDI input node
@export var capture_external_midi_input:bool = true
## Default channel used for external input without channel info
@export_range (0, 15) var external_input_default_channel:int = 0

# -----------------------------------------------------------------------------
# Variables

## MIDI data
var smf_data:SMF.SMFData = null : set = set_smf_data
## MIDI track data (playback-ready data generated from smf_data)
@onready var track_status:GodotMIDIPlayerTrackStatus = GodotMIDIPlayerTrackStatus.new( )
## Current tempo
var tempo:float = 120.0 : set = set_tempo
## Seconds -> timebase conversion factor
var seconds_to_timebase:float = 2.3
## Timebase -> seconds conversion factor
var timebase_to_seconds:float = 1.0 / seconds_to_timebase
## Position
var position:float = 0.0
## Last position
var last_position:int = 0
## Channel status
var channel_status:Array[GodotMIDIPlayerChannelStatus]
## Playback-ready soundfont data
var bank:Bank = null
## AudioStreamPlayer list used for playback
var audio_stream_players:Array[AudioStreamPlayerADSR] = []
## Assign groups for drum tracks
var drum_assign_groups:Dictionary = {
	# Hi-Hats
	42: 42,	# Closed Hi-Hat
	44: 42,	# Pedal Hi-Hat
	46: 42,	# Pedal Hi-Hat
	# Whistle
	71: 71,	# Short Whistle
	72: 71,	# Long Whistle
	# Guiro
	73: 73,	# Short Guiro
	74: 73,	# Long Guiro
	# Cuica
	78: 78,	# Mute Cuica
	79: 78,	# Open Cuica
}
## System Exclusive management
@onready var sys_ex:GodotMIDIPlayerSysEx = GodotMIDIPlayerSysEx.new( )

## MIDI channel prefix
var _midi_channel_prefix:int = 0
## Stores program numbers used in the song
var _used_program_numbers:Array[int] = []
## MIDI channel effects
var channel_audio_effects:Array[GodotMIDIPlayerChannelAudioEffect] = []
## Cached channel bus names to avoid per-event string formatting
var _midi_channel_bus_names:Array[String] = []
## Cached channel bus indices to avoid repeated AudioServer lookup
var _midi_channel_bus_indices:Array[int] = []
## Active voices grouped by MIDI channel
var _active_players_by_channel:Array[Array] = []
## Active voices grouped by MIDI channel and key number
var _active_players_by_channel_key:Array[Dictionary] = []
## Reverse index: player instance id -> { player, channel, key }
var _active_player_meta:Dictionary = {}
## Pan strength
var pan_power:float = 1.0
## Reverb strength
var reverb_power:float = 0.5
## Chorus strength
var chorus_power:float = 0.7
## Whether playback is prepared
var prepared_to_play:bool = false
## Whether AudioServer is initialized
var is_audio_server_inited:bool = false
# 
var _previous_time:float
## External MIDI input node
var _midi_events_source:Node = null

# -----------------------------------------------------------------------------
# Signals

## Tempo changed
signal changed_tempo( tempo )
## Text event
signal appeared_text_event( text )
## Copyright information
signal appeared_copyright( copyright )
## Track name
signal appeared_track_name( channel_number, name )
## Instrument name
signal appeared_instrument_name( channel_number, name )
## Lyric
signal appeared_lyric( lyric )
## Marker
signal appeared_marker( marker )
## Cue point
signal appeared_cue_point( cue_point )
## GM System on
signal appeared_gm_system_on
## GS reset
signal appeared_gs_reset
## XG System on
signal appeared_xg_system_on
## Raw MIDI event
signal midi_event( channel, event )
## Playback note-on event (SMF track playback only)
signal playback_note_on( channel_number, note, velocity )
## Playback note-off event (SMF track playback only)
signal playback_note_off( channel_number, note )
## On loop
signal looped
## Finished
signal finished

## Setup
func _ready( ):
	self._midi_channel_bus_names.resize( max_channel )
	self._midi_channel_bus_indices.resize( max_channel )
	for i in range( max_channel ):
		self._midi_channel_bus_names[i] = self.midi_channel_bus_name % i
		self._midi_channel_bus_indices[i] = -1

	if AudioServer.get_bus_index( self.midi_master_bus_name ) == -1:
		AudioServer.add_bus( -1 )
		var midi_master_bus_idx:int = AudioServer.get_bus_count( ) - 1
		AudioServer.set_bus_name( midi_master_bus_idx, self.midi_master_bus_name )
		AudioServer.set_bus_send( midi_master_bus_idx, self.bus )
		AudioServer.set_bus_volume_db( AudioServer.get_bus_index( self.midi_master_bus_name ), self.volume_db )

		for i in range( 0, 16 ):
			AudioServer.add_bus( -1 )
			var midi_channel_bus_idx:int = AudioServer.get_bus_count( ) - 1
			var channel_bus_name:String = self._midi_channel_bus_names[i]
			AudioServer.set_bus_name( midi_channel_bus_idx, channel_bus_name )
			AudioServer.set_bus_send( midi_channel_bus_idx, self.midi_master_bus_name )
			AudioServer.set_bus_volume_db( midi_channel_bus_idx, 0.0 )
			self._midi_channel_bus_indices[i] = midi_channel_bus_idx

			var cae: = GodotMIDIPlayerChannelAudioEffect.new( )
			cae.ae_panner = AudioEffectPanner.new( )
			cae.ae_reverb = AudioEffectReverb.new( )
			cae.ae_reverb.wet = 0.03
			cae.ae_chorus = AudioEffectChorus.new( )
			cae.ae_chorus.wet = 0.0
			AudioServer.add_bus_effect( midi_channel_bus_idx, cae.ae_chorus )
			AudioServer.add_bus_effect( midi_channel_bus_idx, cae.ae_panner )
			AudioServer.add_bus_effect( midi_channel_bus_idx, cae.ae_reverb )
			self.channel_audio_effects.append( cae )

			# Create stereo sub-buses for stereo sample playback
			# Force left pan
			AudioServer.add_bus( -1 )
			var left_bus_idx:int = AudioServer.get_bus_count( ) - 1
			AudioServer.set_bus_name( left_bus_idx, self.midi_channel_bus_name_left % i )
			AudioServer.set_bus_send( left_bus_idx, channel_bus_name )
			AudioServer.set_bus_volume_db( left_bus_idx, 0.0 )
			var left_panner:AudioEffectPanner = AudioEffectPanner.new( )
			left_panner.pan = -1.0
			AudioServer.add_bus_effect( left_bus_idx, left_panner )
			# Force right pan
			AudioServer.add_bus( -1 )
			var right_bus_idx:int = AudioServer.get_bus_count( ) - 1
			AudioServer.set_bus_name( right_bus_idx, self.midi_channel_bus_name_right % i )
			AudioServer.set_bus_send( right_bus_idx, channel_bus_name )
			AudioServer.set_bus_volume_db( right_bus_idx, 0.0 )
			var right_panner:AudioEffectPanner = AudioEffectPanner.new( )
			right_panner.pan = 1.0
			AudioServer.add_bus_effect( right_bus_idx, right_panner )
	else:
		for i in range( 0, 16 ):
			var midi_channel_bus_idx:int = 0
			for k in range( AudioServer.get_bus_count( ) ):
				if AudioServer.get_bus_name( k ) == self._midi_channel_bus_names[i]:
					midi_channel_bus_idx = k
					break
			self._midi_channel_bus_indices[i] = midi_channel_bus_idx

			var cae: = GodotMIDIPlayerChannelAudioEffect.new( )
			for k in range( AudioServer.get_bus_effect_count( midi_channel_bus_idx ) ):
				var ae: = AudioServer.get_bus_effect( midi_channel_bus_idx, k )
				if ae is AudioEffectPanner:
					cae.ae_panner = ae
				elif ae is AudioEffectReverb:
					cae.ae_reverb = ae
				elif ae is AudioEffectChorus:
					cae.ae_chorus = ae
			self.channel_audio_effects.append( cae )
	self.is_audio_server_inited = true

	self.channel_status = []
	for i in range( max_channel ):
		var drum_track:bool = ( i == drum_track_channel )
		var _bank:int = 0
		if drum_track:
			_bank = Bank.drum_track_bank
		self.channel_status.append( GodotMIDIPlayerChannelStatus.new( i, _bank, drum_track ) )

	self.set_max_polyphony( self.max_polyphony )
	self.set_volume_db( self.volume_db )
	if self.capture_external_midi_input:
		self._connect_midi_events_source( )

	if self.playing:
		self.play( )

## Notification
## @param	what	Notification reason
func _notification( what:int ):
	# On dispose
	if what == NOTIFICATION_PREDELETE:
		pass
		# Keep these for reuse, so do not remove them
		#AudioServer.remove_bus( AudioServer.get_bus_index( self.midi_master_bus_name ) )
		#for i in range( 0, 16 ):
		#	AudioServer.remove_bus( AudioServer.get_bus_index( self.midi_channel_bus_name % i ) )

## Initialization before playback
func _prepare_to_play( ) -> bool:
	# Load file
	if self.smf_data == null:
		var smf_reader: = SMF.new( )
		var result: = smf_reader.read_file( self.file )
		if result.error == OK:
			self.smf_data = result.data
			self.playing = true
		else:
			self.smf_data = null
			self.playing = false
			return false

	self.sys_ex.initialize( )
	self._init_track( )
	self._analyse_smf( )
	self._init_channel( )

	# Force soundfont reload
	if not self.load_all_voices_from_soundfont:
		self.set_soundfont( self.soundfont )

	return true

## Initialize tracks
func _init_track( ) -> void:
	var track_status_events:Array[SMF.MIDIEventChunk] = []

	if len( self.smf_data.tracks ) == 1:
		track_status_events = self.smf_data.tracks[0].events
	else:
		# Mix multiple tracks to single track
		var tracks:Array[Dictionary] = []
		var track_id:int = 0
		for track in self.smf_data.tracks:
			tracks.append({"track_id": track_id, "pointer":0, "events":track.events, "length": len( track.events )})
			track_id += 1

		var time:int = 0
		var finished:bool = false
		while not finished:
			finished = true

			var next_time:int = 0x7fffffff
			for track in tracks:
				var p = track.pointer
				if track.length <= p: continue
				finished = false
				
				var e:SMF.MIDIEventChunk = track.events[p]
				var e_time:int = e.time
				if e_time == time:
					track_status_events.append( e )
					track.pointer += 1
					next_time = e_time
				elif e_time < next_time:
					next_time = e_time
			time = next_time

	self.last_position = track_status_events[len(track_status_events)-1].time
	self.track_status.events = track_status_events
	self.track_status.event_pointer = 0

## Analyze SMF
func _analyse_smf( ) -> void:
	var channels:Array[Dictionary] = []
	for i in range( max_channel ):
		channels.append({ "number": i, "bank": 0, })
	self.loop_start = 0.0
	self._used_program_numbers = [0, Bank.drum_track_bank << 7]	# GrandPiano and Standard Kit

	for event_chunk in self.track_status.events:
		var channel_number:int = event_chunk.channel_number
		var channel = channels[channel_number]
		var event = event_chunk.event

		match event.type:
			SMF.MIDIEventType.program_change:
				var program_number:int = event.number | ( channel.bank << 7 )
				if not( event.number in self._used_program_numbers ):
					self._used_program_numbers.append( event.number )
				if not( program_number in self._used_program_numbers ):
					self._used_program_numbers.append( program_number )
			SMF.MIDIEventType.control_change:
				match event.number:
					SMF.control_number_bank_select_msb:
						if channel.number == drum_track_channel:
							channel.bank = Bank.drum_track_bank
						else:
							channel.bank = ( channel.bank & 0x7F ) | ( event.value << 7 )
					SMF.control_number_bank_select_lsb:
						if channel.number == drum_track_channel:
							channel.bank = Bank.drum_track_bank
						else:
							channel.bank = ( channel.bank & 0x3F80 ) | ( event.value & 0x7F )
					SMF.control_number_tkool_loop_point:
						self.loop_start = float( event_chunk.time )
			_:
				pass

## Initialize channels
func _init_channel( ) -> void:
	for channel in self.channel_status:
		channel.initialize( )

## Play
## @param	from_position	Playback position
func play( from_position:float = 0.0 ) -> void:
	self._previous_time = 0.0
	if not self._prepare_to_play( ):
		self.playing = false
		return
	self.playing = true
	if from_position == 0.0:
		self.position = 0.0
		self.track_status.event_pointer = 0
	else:
		self.seek( from_position )

## Seek
## @param	from_position	Playback position
func seek( to_position:float ) -> void:
	self._previous_time = 0.0
	self._stop_all_notes( )
	self.position = to_position

	var new_position:int = int( floor( self.position ) )
	var pointer:int = self._find_event_pointer_for_time( new_position )
	for i in range( pointer ):
		var event_chunk:SMF.MIDIEventChunk = self.track_status.events[i]

		var channel:GodotMIDIPlayerChannelStatus = self.channel_status[event_chunk.channel_number]
		var event:SMF.MIDIEvent = event_chunk.event

		match event.type:
			SMF.MIDIEventType.program_change:
				channel.program = ( event as SMF.MIDIEventProgramChange ).number
			SMF.MIDIEventType.control_change:
				var event_control_change:SMF.MIDIEventControlChange = event as SMF.MIDIEventControlChange
				self._process_track_event_control_change( channel, event_control_change.number, event_control_change.value )
			SMF.MIDIEventType.pitch_bend:
				self._process_pitch_bend( channel, ( event as SMF.MIDIEventPitchBend ).value )
			SMF.MIDIEventType.system_event:
				self._process_track_system_event( channel, event as SMF.MIDIEventSystemEvent )
			_:
				# Ignore
				pass
	self.track_status.event_pointer = pointer

## Find first event pointer at/after specified time
## @param	timebase_position	Track position in timebase units
## @return		Event pointer index
func _find_event_pointer_for_time( timebase_position:int ) -> int:
	var events:Array[SMF.MIDIEventChunk] = self.track_status.events
	var left:int = 0
	var right:int = len( events )
	while left < right:
		var middle:int = ( left + right ) >> 1
		if events[middle].time < timebase_position:
			left = middle + 1
		else:
			right = middle
	return left

## Stop
func stop( ) -> void:
	self._previous_time = 0.0
	self._stop_all_notes( )
	self.playing = false

## Force-send reset command
func send_reset( ) -> void:
	self._process_track_sys_ex_reset_all_channels( )

## Set file
## @param	path	File path
func set_file( path:String ) -> void:
	file = path
	self.stop( )
	self.smf_data = null

## Set polyphony
## @param	mp	Polyphony
func set_max_polyphony( mp:int ) -> void:
	max_polyphony = mp

	# Remove
	for asp in self.audio_stream_players:
		self.remove_child( asp )

	# Recreate
	self.audio_stream_players = []
	self._reset_voice_index( )
	for i in range( max_polyphony ):
		var audio_stream_player:AudioStreamPlayerADSR = ADSR.instantiate( )
		audio_stream_player.mix_target = self.mix_target
		audio_stream_player.bus = self.bus
		self.add_child( audio_stream_player )
		self.audio_stream_players.append( audio_stream_player )

## Reset voice indices
func _reset_voice_index( ) -> void:
	self._active_players_by_channel = []
	self._active_players_by_channel_key = []
	for i in range( max_channel ):
		self._active_players_by_channel.append( [] )
		self._active_players_by_channel_key.append( {} )
	self._active_player_meta.clear( )

## Register currently used voice in indices
func _register_active_voice( audio_stream_player:AudioStreamPlayerADSR, channel_number:int, key_number:int ) -> void:
	var player_id:int = audio_stream_player.get_instance_id( )
	if self._active_player_meta.has( player_id ):
		self._unregister_active_voice_by_id( player_id )

	var channel_players:Array = self._active_players_by_channel[channel_number]
	channel_players.append( audio_stream_player )

	var channel_key_map:Dictionary = self._active_players_by_channel_key[channel_number]
	var key_players:Array = channel_key_map.get( key_number, [] )
	key_players.append( audio_stream_player )
	channel_key_map[key_number] = key_players

	self._active_player_meta[player_id] = {
		"player": audio_stream_player,
		"channel": channel_number,
		"key": key_number,
	}

## Unregister voice by object
func _unregister_active_voice( audio_stream_player:AudioStreamPlayerADSR ) -> void:
	self._unregister_active_voice_by_id( audio_stream_player.get_instance_id( ) )

## Unregister voice by instance id
func _unregister_active_voice_by_id( player_id:int ) -> void:
	if not self._active_player_meta.has( player_id ):
		return

	var meta:Dictionary = self._active_player_meta[player_id]
	var audio_stream_player:AudioStreamPlayerADSR = meta["player"]
	var channel_number:int = meta["channel"]
	var key_number:int = meta["key"]

	var channel_players:Array = self._active_players_by_channel[channel_number]
	var channel_idx:int = channel_players.find( audio_stream_player )
	if channel_idx != -1:
		channel_players.remove_at( channel_idx )

	var channel_key_map:Dictionary = self._active_players_by_channel_key[channel_number]
	if channel_key_map.has( key_number ):
		var key_players:Array = channel_key_map[key_number]
		var key_idx:int = key_players.find( audio_stream_player )
		if key_idx != -1:
			key_players.remove_at( key_idx )
		if len( key_players ) == 0:
			channel_key_map.erase( key_number )
		else:
			channel_key_map[key_number] = key_players

	self._active_player_meta.erase( player_id )

## Drop stale voices from indices (e.g. after release completes)
func _cleanup_inactive_voice_index( ) -> void:
	if self._active_player_meta.is_empty( ):
		return

	var stale_player_ids:Array[int] = []
	for player_id in self._active_player_meta.keys( ):
		var meta:Dictionary = self._active_player_meta[player_id]
		var audio_stream_player:AudioStreamPlayerADSR = meta["player"]
		if audio_stream_player == null or not audio_stream_player.playing:
			stale_player_ids.append( player_id )

	for stale_player_id in stale_player_ids:
		self._unregister_active_voice_by_id( stale_player_id )

## Set soundfont
## @param	path	File path
func set_soundfont( path:String ) -> void:
	soundfont = path

	if path == null or path == "":
		self.bank = null
		return

	var sf_reader: = SoundFont.new( )
	var result: = sf_reader.read_file( soundfont )

	if result.error == OK:
		self.bank = Bank.new( )
		if self.load_all_voices_from_soundfont:
			self.bank.read_soundfont( result.data )
		else:
			self.bank.read_soundfont( result.data, self._used_program_numbers )

## Update SMF data
## @param	sd	SMF data
func set_smf_data( sd:SMF.SMFData ) -> void:
	smf_data = sd
	self.stop( )

## Set tempo
## @param	bpm	Tempo
func set_tempo( bpm:float ) -> void:
	tempo = bpm
	self.seconds_to_timebase = tempo / 60.0
	self.timebase_to_seconds = 60.0 / tempo
	self.emit_signal( "changed_tempo", bpm )

## Set volume
## @param	vdb	Volume
func set_volume_db( vdb:float ) -> void:
	volume_db = vdb
	if not self.is_audio_server_inited:
		return

	AudioServer.set_bus_volume_db( AudioServer.get_bus_index( self.midi_master_bus_name ), self.volume_db )

## Stop all notes
func _stop_all_notes( ) -> void:
	for audio_stream_player in self.audio_stream_players:
		audio_stream_player.hold = false
		audio_stream_player.note_stop( )

	for channel in self.channel_status:
		channel.note_on.clear( )
	self._reset_voice_index( )

## Per-frame processing
## @param	delta
func _process( delta:float ) -> void:
	if self.smf_data != null:
		if self.playing:
			self.position += float( self.smf_data.timebase ) * delta * self.seconds_to_timebase * self.play_speed
			self._process_track( )

	for asp in self.audio_stream_players:
		asp._update_adsr( delta )
	self._cleanup_inactive_voice_index( )

## Track processing
## @return	Number of executed events
func _process_track( ) -> int:
	var track:GodotMIDIPlayerTrackStatus = self.track_status
	if track.events == null:
		return 0

	var length:int = len( track.events )

	if length <= track.event_pointer:
		if self.loop:
			var diff:float = self.position - track.events[len( track.events ) - 1].time
			self.seek( self.loop_start )
			self.emit_signal( "looped" )
			self.position += diff
		else:
			self.playing = false
			self.emit_signal( "finished" )
			return 0

	var execute_event_count:int = 0
	var current_position:int = int( ceil( self.position ) )

	while track.event_pointer < length:
		var event_chunk:SMF.MIDIEventChunk = track.events[track.event_pointer]
		if current_position <= event_chunk.time:
			break
		track.event_pointer += 1
		execute_event_count += 1

		var channel:GodotMIDIPlayerChannelStatus = self.channel_status[event_chunk.channel_number]
		var event:SMF.MIDIEvent = event_chunk.event

		self.emit_signal( "midi_event", channel, event )

		match event.type:
			SMF.MIDIEventType.note_off:
				var note_off_event:SMF.MIDIEventNoteOff = event as SMF.MIDIEventNoteOff
				self._process_track_event_note_off( channel, note_off_event.note )
				self.emit_signal( "playback_note_off", channel.number, note_off_event.note )
			SMF.MIDIEventType.note_on:
				var event_note_on:SMF.MIDIEventNoteOn = event as SMF.MIDIEventNoteOn
				self._process_track_event_note_on( channel, event_note_on.note, event_note_on.velocity )
				self.emit_signal( "playback_note_on", channel.number, event_note_on.note, event_note_on.velocity )
			SMF.MIDIEventType.program_change:
				channel.program = ( event as SMF.MIDIEventProgramChange ).number
			SMF.MIDIEventType.control_change:
				var event_control_change:SMF.MIDIEventControlChange = event as SMF.MIDIEventControlChange
				self._process_track_event_control_change( channel, event_control_change.number, event_control_change.value )
			SMF.MIDIEventType.pitch_bend:
				self._process_pitch_bend( channel, ( event as SMF.MIDIEventPitchBend ).value )
			SMF.MIDIEventType.system_event:
				self._process_track_system_event( channel, event as SMF.MIDIEventSystemEvent )
			_:
				# Ignore
				pass

	return execute_event_count

## Raw MIDI message processing
## @param	input_event	Event
func receive_raw_midi_message( input_event:InputEventMIDI ) -> void:
	var channel:GodotMIDIPlayerChannelStatus = self._get_channel_status( input_event.channel )
	if channel == null:
		return

	match input_event.message:
		MIDI_MESSAGE_NOTE_OFF:
			self._process_track_event_note_off( channel, input_event.pitch )
		MIDI_MESSAGE_NOTE_ON:
			self._process_track_event_note_on( channel, input_event.pitch, input_event.velocity )
		MIDI_MESSAGE_AFTERTOUCH:
			# Polyphonic key pressure is not implemented by the player yet
			pass
		MIDI_MESSAGE_CONTROL_CHANGE:
			self._process_track_event_control_change( channel, input_event.controller_number, input_event.controller_value )
		MIDI_MESSAGE_PROGRAM_CHANGE:
			channel.program = input_event.instrument
		MIDI_MESSAGE_CHANNEL_PRESSURE:
			# Channel pressure is not implemented by the player yet
			pass
		MIDI_MESSAGE_PITCH_BEND:
			var fixed_pitch:int = input_event.pitch
			self._process_pitch_bend( channel, fixed_pitch )
		0x0F:
			# InputEventMIDI does not provide MIDI System Events
			pass
		_:
			print( "unknown message %x" % input_event.message )
			breakpoint

## Receive channel-specific note on
func receive_note_on( channel_number:int, note:int, velocity:int ) -> void:
	var channel:GodotMIDIPlayerChannelStatus = self._get_channel_status( channel_number )
	if channel == null:
		return
	if velocity <= 0:
		self._process_track_event_note_off( channel, note )
	else:
		self._process_track_event_note_on( channel, note, velocity )

## Receive channel-specific note off
func receive_note_off( channel_number:int, note:int ) -> void:
	var channel:GodotMIDIPlayerChannelStatus = self._get_channel_status( channel_number )
	if channel == null:
		return
	self._process_track_event_note_off( channel, note )

## Receive channel-specific control change
func receive_control_change( channel_number:int, control_number:int, value:int ) -> void:
	var channel:GodotMIDIPlayerChannelStatus = self._get_channel_status( channel_number )
	if channel == null:
		return
	self._process_track_event_control_change( channel, control_number, value )

## Receive channel-specific program change
func receive_program_change( channel_number:int, instrument:int ) -> void:
	var channel:GodotMIDIPlayerChannelStatus = self._get_channel_status( channel_number )
	if channel == null:
		return
	channel.program = clamp( instrument, 0, max_program_number - 1 )

## Receive channel-specific pitch bend
func receive_pitch_bend( channel_number:int, value:int ) -> void:
	var channel:GodotMIDIPlayerChannelStatus = self._get_channel_status( channel_number )
	if channel == null:
		return
	self._process_pitch_bend( channel, value )

## Set instrument per channel
## @param	channel_number	Target channel
## @param	program_number	Program number
## @param	bank_msb		Optional. If 0-127, updates MSB
## @param	bank_lsb		Optional. If 0-127, updates LSB
func set_channel_instrument( channel_number:int, program_number:int, bank_msb:int = -1, bank_lsb:int = -1 ) -> void:
	var channel:GodotMIDIPlayerChannelStatus = self._get_channel_status( channel_number )
	if channel == null:
		return

	channel.program = clamp( program_number, 0, max_program_number - 1 )
	if 0 <= bank_msb and bank_msb < 128:
		channel.bank = ( channel.bank & 0x7F ) | ( bank_msb << 7 )
	if 0 <= bank_lsb and bank_lsb < 128:
		channel.bank = ( channel.bank & 0x3F80 ) | bank_lsb

## Assign instruments to multiple channels at once
## Accepts values as int(program) or Dictionary { program, bank_msb, bank_lsb }
func set_channel_instruments( assignments:Dictionary ) -> void:
	for channel_key in assignments.keys( ):
		var channel_number:int = int( channel_key )
		var assignment = assignments[channel_key]
		if assignment is int:
			self.set_channel_instrument( channel_number, assignment )
		elif assignment is Dictionary:
			var data:Dictionary = assignment
			if not data.has( "program" ):
				continue
			self.set_channel_instrument(
				channel_number,
				int( data["program"] ),
				int( data.get( "bank_msb", -1 ) ),
				int( data.get( "bank_lsb", -1 ) )
			)

## Connect to external MIDI input node
func _connect_midi_events_source( ) -> void:
	var source:Node = null
	if self.midi_events_node_path != NodePath( ):
		source = get_node_or_null( self.midi_events_node_path )
	if source == null:
		source = get_node_or_null( "/root/MidiEvents" )
	if source == null:
		return

	self._midi_events_source = source
	var raw_callable:Callable = Callable( self, "_on_external_midi_input" )
	if source.has_signal( "midi_input" ):
		if not source.is_connected( "midi_input", raw_callable ):
			source.connect( "midi_input", raw_callable )

	var note_on_channel_callable:Callable = Callable( self, "_on_external_note_on" )
	var note_off_channel_callable:Callable = Callable( self, "_on_external_note_off" )
	var control_change_channel_callable:Callable = Callable( self, "_on_external_control_change" )
	var program_change_callable:Callable = Callable( self, "_on_external_program_change" )
	var pitch_bend_callable:Callable = Callable( self, "_on_external_pitch_bend" )
	if source.has_signal( "note_on_channel" ) and not source.is_connected( "note_on_channel", note_on_channel_callable ):
		source.connect( "note_on_channel", note_on_channel_callable )
	if source.has_signal( "note_off_channel" ) and not source.is_connected( "note_off_channel", note_off_channel_callable ):
		source.connect( "note_off_channel", note_off_channel_callable )
	if source.has_signal( "control_change_channel" ) and not source.is_connected( "control_change_channel", control_change_channel_callable ):
		source.connect( "control_change_channel", control_change_channel_callable )
	if source.has_signal( "program_change" ) and not source.is_connected( "program_change", program_change_callable ):
		source.connect( "program_change", program_change_callable )
	if source.has_signal( "pitch_bend" ) and not source.is_connected( "pitch_bend", pitch_bend_callable ):
		source.connect( "pitch_bend", pitch_bend_callable )

## Get channel status from a channel number
func _get_channel_status( channel_number:int ) -> GodotMIDIPlayerChannelStatus:
	if len( self.channel_status ) == 0:
		return null
	var fixed_channel:int = clamp( channel_number, 0, max_channel - 1 )
	return self.channel_status[fixed_channel]

func _on_external_midi_input( midi_event:InputEventMIDI ) -> void:
	self.receive_raw_midi_message( midi_event )

func _on_external_note_on( channel:int, pitch:int, velocity:int ) -> void:
	self.receive_note_on( channel, pitch, velocity )

func _on_external_note_off( channel:int, pitch:int ) -> void:
	self.receive_note_off( channel, pitch )

func _on_external_control_change( channel:int, id:int, value:int ) -> void:
	self.receive_control_change( channel, id, value )

func _on_external_program_change( channel:int, instrument:int ) -> void:
	self.receive_program_change( channel, instrument )

func _on_external_pitch_bend( channel:int, value:int ) -> void:
	self.receive_pitch_bend( channel, value )

## Pitch bend processing
## @param	channel	Channel status
## @param	value	Value
func _process_pitch_bend( channel:GodotMIDIPlayerChannelStatus, value:int ) -> void:
	var pb:float = float( value ) / 8192.0 - 1.0
	var pbs:float = channel.rpn.pitch_bend_sensitivity
	channel.pitch_bend = pb

	self._apply_channel_pitch_bend( channel )

## Track event: note off processing
## @param	channel				Channel status
## @param	note				Note number
## @param	force_disable_hold	Force-ignore Hold 1
func _process_track_event_note_off( channel:GodotMIDIPlayerChannelStatus, note:int, force_disable_hold:bool = false ) -> void:
	var track_key_shift:int = self.key_shift if not channel.drum_track else 0
	var key_number:int = note + track_key_shift
	if channel.note_on.erase( key_number ):
		pass

	if channel.drum_track: return

	var channel_key_map:Dictionary = self._active_players_by_channel_key[channel.number]
	if not channel_key_map.has( key_number ):
		return
	var key_players:Array = ( channel_key_map[key_number] as Array ).duplicate( )
	for asp in key_players:
		if not asp.playing:
			self._unregister_active_voice( asp )
			continue
		if force_disable_hold:
			asp.hold = false
		asp.start_release( )

## Track event: note on processing
## @param	channel				Channel status
## @param	note				Note number
## @param	velocity			Velocity
func _process_track_event_note_on( channel:GodotMIDIPlayerChannelStatus, note:int, velocity:int ) -> void:
	if channel.mute: return
	if self.bank == null: return

	var track_key_shift:int = self.key_shift if not channel.drum_track else 0
	var key_number:int = note + track_key_shift
	var preset:Bank.Preset = self.bank.get_preset( channel.program, channel.bank )
	if preset.instruments[key_number] == null:
		return
	var instruments:Array = preset.instruments[key_number] # Bank.Instrument

	var assign_group:int = key_number
	if channel.drum_track:
		if key_number in self.drum_assign_groups:
			assign_group = self.drum_assign_groups[key_number]

	if channel.note_on.has( assign_group ):
		self._process_track_event_note_off( channel, note, true )

	var matched_instruments:Array = []
	for instrument in instruments:
		if instrument.vel_range_min <= velocity and velocity <= instrument.vel_range_max:
			matched_instruments.append( instrument )
	var polyphony_count:int = len( matched_instruments )
	if polyphony_count == 0:
		return

	# Play each player
	var channel_bus_name:String = self._midi_channel_bus_names[channel.number]
	for instrument in matched_instruments:
		var note_player:AudioStreamPlayerADSR = self._get_idle_player( )
		if note_player != null:
			note_player.channel_number = channel.number
			note_player.key_number = key_number
			note_player.bus = channel_bus_name
			note_player.velocity = velocity
			note_player.pitch_bend = channel.pitch_bend
			note_player.pitch_bend_sensitivity = channel.rpn.pitch_bend_sensitivity
			note_player.modulation = channel.modulation
			note_player.modulation_sensitivity = channel.rpn.modulation_sensitivity
			note_player.auto_release_mode = channel.drum_track
			note_player.polyphony_count = float( polyphony_count )
			note_player.note_stop( )
			note_player.set_instrument( instrument )
			note_player.hold = channel.hold
			note_player.note_play( 0.0 )
			self._register_active_voice( note_player, channel.number, key_number )

	channel.note_on[ assign_group ] = true

## Track event: control change processing
## @param	channel	Channel status
## @param	number	Event number
## @param	value	Value
func _process_track_event_control_change( channel:GodotMIDIPlayerChannelStatus, number:int, value:int ) -> void:
	match number:
		SMF.control_number_volume:
			channel.volume = float( value ) / 127.0
			self._apply_channel_volume( channel )
		SMF.control_number_modulation:
			channel.modulation = float( value ) / 127.0
			self._apply_channel_modulation( channel )
		SMF.control_number_expression:
			channel.expression = float( value ) / 127.0
			self._apply_channel_volume( channel )
		SMF.control_number_reverb_send_level:
			channel.reverb = float( value ) / 127.0
			self._apply_channel_reverb( channel )
		SMF.control_number_tremolo_depth:
			channel.tremolo = float( value ) / 127.0
		SMF.control_number_chorus_send_level:
			channel.chorus = float( value ) / 127.0
			self._apply_channel_chorus( channel )
		SMF.control_number_celeste_depth:
			channel.celeste = float( value ) / 127.0
		SMF.control_number_phaser_depth:
			channel.phaser = float( value ) / 127.0
		SMF.control_number_pan:
			channel.pan = float( value ) / 127.0
			self._apply_channel_pan( channel )
		SMF.control_number_hold:
			channel.hold = 64 <= value
			self._apply_channel_hold( channel )
		SMF.control_number_portamento:
			channel.portamento = float( value ) / 127.0
		SMF.control_number_sostenuto:
			channel.sostenuto = float( value ) / 127.0
		SMF.control_number_freeze:
			channel.freeze = float( value ) / 127.0
		SMF.control_number_bank_select_msb:
			if channel.drum_track:
				channel.bank = Bank.drum_track_bank
			else:
				if value == 1:
					# In SoundFont, MSB=1 maps to drum track, so avoid it
					value = 0
				channel.bank = ( channel.bank & 0x7F ) | ( value << 7 )
		SMF.control_number_bank_select_lsb:
			if channel.drum_track:
				channel.bank = Bank.drum_track_bank
			else:
				channel.bank = ( channel.bank & 0x3F80 ) | ( value & 0x7F )
		SMF.control_number_rpn_lsb:
			channel.rpn.selected_lsb = value
		SMF.control_number_rpn_msb:
			channel.rpn.selected_msb = value
		SMF.control_number_data_entry_msb:
			self._process_track_event_control_change_rpn_data_entry_msb( channel, value )
		SMF.control_number_data_entry_lsb:
			self._process_track_event_control_change_rpn_data_entry_lsb( channel, value )
		SMF.control_number_all_sound_off:
			self._stop_all_notes( )
		SMF.control_number_all_note_off:
			var channel_players:Array = ( self._active_players_by_channel[channel.number] as Array ).duplicate( )
			for asp in channel_players:
				if not asp.playing:
					self._unregister_active_voice( asp )
					continue
				asp.hold = false
				asp.start_release( )
				if channel.note_on.erase( asp.key_number ):
					pass
		_:
			# Ignore
			pass

## Update channel status
## @param	channel	Channel status
func update_channel_status( channel:GodotMIDIPlayerChannelStatus ) -> void:
	self._apply_channel_volume( channel )
	self._apply_channel_pitch_bend( channel )
	self._apply_channel_modulation( channel )
	self._apply_channel_hold( channel )
	self._apply_channel_reverb( channel )
	self._apply_channel_chorus( channel )
	self._apply_channel_pan( channel )

## Apply volume to channel
## @param	channel	Channel status
func _apply_channel_volume( channel:GodotMIDIPlayerChannelStatus ) -> void:
	var bus_index:int = self._midi_channel_bus_indices[channel.number]
	if bus_index == -1:
		bus_index = AudioServer.get_bus_index( self._midi_channel_bus_names[channel.number] )
		self._midi_channel_bus_indices[channel.number] = bus_index
	AudioServer.set_bus_volume_db( bus_index, linear_to_db( channel.volume * channel.expression ) )

## Apply pitch bend to channel
## @param	channel	Channel status
func _apply_channel_pitch_bend( channel:GodotMIDIPlayerChannelStatus ) -> void:
	var pbs:float = channel.rpn.pitch_bend_sensitivity
	var pb:float = channel.pitch_bend
	for asp in self._active_players_by_channel[channel.number]:
		if asp.playing and ( not asp.request_release ):
			asp.pitch_bend_sensitivity = pbs
			asp.pitch_bend = pb

## Apply reverb to channel
## @param	channel	Channel status
func _apply_channel_reverb( channel:GodotMIDIPlayerChannelStatus ) -> void:
	self.channel_audio_effects[channel.number].ae_reverb.wet = channel.reverb * self.reverb_power

## Apply chorus to channel
## @param	channel	Channel status
func _apply_channel_chorus( channel:GodotMIDIPlayerChannelStatus ) -> void:
	self.channel_audio_effects[channel.number].ae_chorus.wet = channel.chorus * self.chorus_power

## Apply pan to channel
## @param	channel	Channel status
func _apply_channel_pan( channel:GodotMIDIPlayerChannelStatus ):
	self.channel_audio_effects[channel.number].ae_panner.pan = ( ( channel.pan * 2 ) - 1.0 ) * self.pan_power

## Apply modulation to channel
## @param	channel	Channel status
func _apply_channel_modulation( channel:GodotMIDIPlayerChannelStatus ) -> void:
	var ms:float = channel.rpn.modulation_sensitivity
	var m:float = channel.modulation
	for asp in self._active_players_by_channel[channel.number]:
		if asp.playing and ( not asp.request_release ):
			asp.modulation_sensitivity = ms
			asp.modulation = m

## Apply Hold1 to channel
## @param	channel	Channel status
func _apply_channel_hold( channel:GodotMIDIPlayerChannelStatus ) -> void:
	var hold:bool = channel.hold
	for asp in self._active_players_by_channel[channel.number]:
		if asp.playing:
			asp.hold = hold and ( not asp.request_release )

## Track event: set RPN data MSB
## @param	channel	Channel status
## @param	value	Value
func _process_track_event_control_change_rpn_data_entry_msb( channel:GodotMIDIPlayerChannelStatus, value:int ) -> void:
	match channel.rpn.selected_msb:
		0:
			match channel.rpn.selected_lsb:
				SMF.rpn_control_number_pitch_bend_sensitivity:
					channel.rpn.pitch_bend_sensitivity_msb = float( value )
					if 12 < channel.rpn.pitch_bend_sensitivity_msb: channel.rpn.pitch_bend_sensitivity_msb = 12
					channel.rpn.pitch_bend_sensitivity = channel.rpn.pitch_bend_sensitivity_msb + channel.rpn.pitch_bend_sensitivity_lsb / 100.0
				SMF.rpn_control_number_modulation_sensitivity:
					channel.rpn.modulation_sensitivity_msb = float( value )
					channel.rpn.modulation_sensitivity = channel.rpn.modulation_sensitivity_msb + channel.rpn.modulation_sensitivity_lsb / 100.0
				_:
					pass
		_:
			pass

## Track event: set RPN data LSB
## @param	channel	Channel status
## @param	value	Value
func _process_track_event_control_change_rpn_data_entry_lsb( channel:GodotMIDIPlayerChannelStatus, value:int ) -> void:
	match channel.rpn.selected_msb:
		0:
			match channel.rpn.selected_lsb:
				SMF.rpn_control_number_pitch_bend_sensitivity:
					channel.rpn.pitch_bend_sensitivity_lsb = float( value )
					channel.rpn.pitch_bend_sensitivity = channel.rpn.pitch_bend_sensitivity_msb + channel.rpn.pitch_bend_sensitivity_lsb / 100.0
				SMF.rpn_control_number_modulation_sensitivity:
					channel.rpn.modulation_sensitivity_lsb = float( value )
					channel.rpn.modulation_sensitivity = channel.rpn.modulation_sensitivity_msb + channel.rpn.modulation_sensitivity_lsb / 100.0
				_:
					pass
		_:
			pass

## MIDI system event
## @param	channel	Channel status
## @param	event	Event data
func _process_track_system_event( channel:GodotMIDIPlayerChannelStatus, event:SMF.MIDIEventSystemEvent ) -> void:
	match event.args.type:
		SMF.MIDISystemEventType.set_tempo:
			self.tempo = 60000000.0 / float( event.args.bpm )
		SMF.MIDISystemEventType.text_event:
			self.emit_signal( "appeared_text_event", event.args.text )
		SMF.MIDISystemEventType.copyright:
			self.emit_signal( "appeared_copyright", event.args.text )
		SMF.MIDISystemEventType.track_name:
			self.emit_signal( "appeared_track_name", self._midi_channel_prefix, event.args.text )
			self.channel_status[self._midi_channel_prefix].track_name = event.args.text
		SMF.MIDISystemEventType.instrument_name:
			self.emit_signal( "appeared_instrument_name", self._midi_channel_prefix, event.args.text )
			self.channel_status[self._midi_channel_prefix].instrument_name = event.args.text
		SMF.MIDISystemEventType.lyric:
			self.emit_signal( "appeared_lyric", event.args.text )
		SMF.MIDISystemEventType.marker:
			self.emit_signal( "appeared_marker", event.args.text )
		SMF.MIDISystemEventType.cue_point:
			self.emit_signal( "appeared_cue_point", event.args.text )
		SMF.MIDISystemEventType.midi_channel_prefix:
			self._midi_channel_prefix = event.args.channel
		SMF.MIDISystemEventType.sys_ex:
			self._process_track_sys_ex( channel, event.args )
		SMF.MIDISystemEventType.divided_sys_ex:
			self._process_track_sys_ex( channel, event.args )
		_:
			# Ignore
			pass

## MIDI system event: track SysEx processing
## @param	channel		Channel status
## @param	event_args	Event data
func _process_track_sys_ex( channel:GodotMIDIPlayerChannelStatus, event_args ) -> void:
	# Convert for == comparison
	var event_data: = Array( event_args.data )
	var event_data_without_first_data: = event_data.slice( 1, len( event_args.data ) )

	match event_args.manifacture_id:
		SMF.manufacture_id_universal_nopn_realtime_sys_ex:
			if event_data == [0x7f,0x09,0x01,0xf7]:
				self.sys_ex.gm_system_on = true
				self.emit_signal( "appeared_gm_system_on" )
				self._process_track_sys_ex_reset_all_channels( )
		SMF.manufacture_id_roland_corporation:
			if event_data_without_first_data == [0x42,0x12,0x40,0x00,0x7f,0x00,0x41,0xf7]:
				self.sys_ex.gs_reset = true
				self.emit_signal( "appeared_gs_reset" )
				self._process_track_sys_ex_reset_all_channels( )
		SMF.manufacture_id_yamaha_corporation:
			if event_data_without_first_data == [0x4c,0x00,0x00,0x7E,0x00,0xf7]:
				self.sys_ex.xg_system_on = true
				self.emit_signal( "appeared_xg_system_on" )
				self._process_track_sys_ex_reset_all_channels( )

## MIDI system event: reset
func _process_track_sys_ex_reset_all_channels( ) -> void:
	for audio_stream_player in self.audio_stream_players:
		audio_stream_player.hold = false
		audio_stream_player.start_release( )

	for channel in self.channel_status:
		channel.initialize( )
		var bus_index:int = self._midi_channel_bus_indices[channel.number]
		if bus_index == -1:
			bus_index = AudioServer.get_bus_index( self._midi_channel_bus_names[channel.number] )
			self._midi_channel_bus_indices[channel.number] = bus_index
		AudioServer.set_bus_volume_db( bus_index, linear_to_db( float( channel.volume * channel.expression ) ) )
		self.channel_audio_effects[channel.number].ae_reverb.wet = channel.reverb * self.reverb_power
		self.channel_audio_effects[channel.number].ae_chorus.wet = channel.chorus * self.chorus_power
		self.channel_audio_effects[channel.number].ae_panner.pan = ( ( channel.pan * 2 ) - 1.0 ) * self.pan_power

## Get an unused AudioStreamPlayerADSR
## If none are unused, return the AudioStreamPlayerADSR with the longest elapsed time since NoteOn
## @return	AudioStreamPlayerADSR
func _get_idle_player( ) -> AudioStreamPlayerADSR:
	var released_audio_stream_player:AudioStreamPlayerADSR = null
	var minimum_volume_db:float = -80.0
	# var releasing_audio_stream_player:AudioStreamPlayerADSR = null
	var oldest_audio_stream_player:AudioStreamPlayerADSR = null
	var oldest:float = -1.0

	for audio_stream_player in self.audio_stream_players:
		if not audio_stream_player.playing:
			return audio_stream_player
		if audio_stream_player.releasing and audio_stream_player.volume_db < minimum_volume_db:
			released_audio_stream_player = audio_stream_player
			minimum_volume_db = audio_stream_player.volume_db
		if oldest < audio_stream_player.using_timer:
			oldest_audio_stream_player = audio_stream_player
			oldest = audio_stream_player.using_timer

	if released_audio_stream_player != null:
		return released_audio_stream_player

	return oldest_audio_stream_player

## Returns the number of currently sounding voices
## @warning	Affected by multi-layered soundfont instruments. For pure simultaneous note-on count, reference note_on across all channel statuses.
## @return		Current sounding voice count
func get_now_playing_polyphony( ) -> int:
	var polyphony:int = 0
	for audio_stream_player in self.audio_stream_players:
		if audio_stream_player.playing:
			polyphony += 1
	return polyphony

## Load a MIDI file from binary data
## @param	byte_array	MIDI data
## @return	Returns true on success, false on failure
func load_from_bytes( byte_array: PackedByteArray ) -> bool:
	var smf_reader = SMF.new( )
	var result = smf_reader.read_data( byte_array )
	if result.error == OK:
		self.smf_data = result.data
	else:
		self.smf_data = null
		return false

	self.sys_ex.initialize( )
	self._init_track( )
	self._analyse_smf( )
	self._init_channel( )

	if not self.load_all_voices_from_soundfont:
		self.set_soundfont( self.soundfont )

	return true
