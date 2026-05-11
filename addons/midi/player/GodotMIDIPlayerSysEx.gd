##
##	Godot MIDI Player SysEx module by あるる（きのもと 結衣） @arlez80
##
##	MIT License
##

extends RefCounted

## GS Reset
var gs_reset:bool
## GM System on
var gm_system_on:bool
## XG System on
var xg_system_on:bool

## Constructor
func _init():
	self.initialize( )

## Initialize
##
## Reset all received flags.
func initialize( ) -> void:
	self.gs_reset = false
	self.gm_system_on = false
	self.xg_system_on = false
