##
##	Godot MIDI Player channel RPN status module by あるる（きのもと 結衣） @arlez80
##
##	MIT License
##

extends RefCounted

## Selected MSB
var selected_msb:int
## Selected LSB
var selected_lsb:int

## Pitch bend
var pitch_bend_sensitivity:float
var pitch_bend_sensitivity_msb:float
var pitch_bend_sensitivity_lsb:float

## Modulation
var modulation_sensitivity:float
var modulation_sensitivity_msb:float
var modulation_sensitivity_lsb:float

## Constructor
func _init():
	self.initialize( )

## Initialize RPN
func initialize( ) -> void:
	self.selected_msb = 0
	self.selected_lsb = 0

	self.pitch_bend_sensitivity = 2.0
	self.pitch_bend_sensitivity_msb = 2.0
	self.pitch_bend_sensitivity_lsb = 0.0

	self.modulation_sensitivity = 0.25
	self.modulation_sensitivity_msb = 0.25
	self.modulation_sensitivity_lsb = 0.0
