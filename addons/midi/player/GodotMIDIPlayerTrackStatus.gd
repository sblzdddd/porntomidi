##
##	Godot MIDI Player track status module by あるる（きのもと 結衣） @arlez80
##
##	MIT License
##

extends RefCounted

## Events
var events:Array[SMF.MIDIEventChunk] = []
## Event pointer
var event_pointer:int = 0
