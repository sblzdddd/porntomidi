##
##	Godot MIDI Player channel status module by あるる（きのもと 結衣） @arlez80
##
##	MIT License
##

extends RefCounted

const GodotMIDIPlayerChannelStatusRPN = preload( "GodotMIDIPlayerChannelStatusRPN.gd" )

## Channel number
var number:int
## Track name
var track_name:String
## Instrument name
var instrument_name:String
## Note-on list
var note_on:Dictionary
## Channel mute
var mute:bool

## Selected bank number
var bank:int
## Program number
var program:int
## Pitch bend value
var pitch_bend:float

## Volume value
var volume:float
## Expression value
var expression:float
## Reverb: Effect 1
var reverb:float
## Tremolo: Effect 2
var tremolo:float
## Chorus: Effect 3
var chorus:float
## Celeste: Effect 4
var celeste:float
## Phaser: Effect 5
var phaser:float
## Modulation
var modulation:float
## Hold / Damper (Hold 1)
var hold:bool
## Portamento
var portamento:float
## Sostenuto
var sostenuto:float
## Freeze (Hold 2)
var freeze:bool
## Pan
var pan:float

## Is drum track?
var drum_track:bool

## RPN status
var rpn:GodotMIDIPlayerChannelStatusRPN

## Constructor
## @param	_number		Channel number
## @param	_bank		Bank number
## @param	_drum_track	Whether this is a drum track
func _init(_number:int,_bank:int = 0,_drum_track:bool = false):
	self.number = _number
	self.track_name = "Track %d" % _number
	self.instrument_name = "Track %d" % _number
	self.mute = false
	self.bank = _bank
	self.drum_track = _drum_track
	self.rpn = GodotMIDIPlayerChannelStatusRPN.new( )
	self.initialize( )

## Notification (for memory disposal)
## @param	what	Notification reason
func _notification( what:int ):
	if what == NOTIFICATION_PREDELETE:
		self.note_on.clear( )

## Initialize channel
func initialize( ) -> void:
	self.note_on = {}
	self.program = 0

	self.pitch_bend = 0.0
	self.volume = 100.0 / 127.0
	self.expression = 1.0
	self.reverb = 0.0
	self.tremolo = 0.0
	self.chorus = 0.0
	self.celeste = 0.0
	self.phaser = 0.0
	self.modulation = 0.0
	self.hold = false
	self.portamento = 0.0
	self.sostenuto = 0.0
	self.freeze = false
	self.pan = 0.5

	self.rpn.initialize( )
