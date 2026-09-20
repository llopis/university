class_name Player


var pos: Vector2
var vel: Vector2

const Speed: float = 500

func tick(dt: float) -> void:
	pos += dt*Speed*vel
