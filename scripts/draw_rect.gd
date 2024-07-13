class_name DrawRect
extends Object

var position : Vector2:
	set(value):
		position = value
		rect.position = value
		
		set_end()

var size : Vector2:
	set(value):
		size = value
		rect.size = value
		
		set_end()

var end : Vector2

var rect : Rect2

var color : Color

var difference

func set_end():
	end = position + size
