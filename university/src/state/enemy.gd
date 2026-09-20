class_name Enemy


var pos: Vector2
var dir: Vector2
var targetPos: Vector2
var speed: float = 0


func _init() -> void:
	_chooseNewTargetPos()


func tick(dt: float) -> void:
	var beforeDistSq: float = (targetPos - pos).length_squared()
	pos += speed*dt*dir
	var afterDistSq: float = (targetPos - pos).length_squared()
	if (afterDistSq >= beforeDistSq):
		_chooseNewTargetPos()
	

func _chooseNewTargetPos() -> void:
	speed = randf_range(70, 120)
	const Margin: float = 50
	targetPos = Vector2(randf_range(Margin, Level.WorldWidth - Margin), randf_range(Margin, Level.WorldHeight - Margin))
	
	var toTarget: Vector2 = targetPos - pos
	var distSq: float = toTarget.length_squared()
	if (distSq > 0.00001):
		dir = toTarget.normalized()
	else:
		dir = Vector2(0,0)
