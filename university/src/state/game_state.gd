class_name GameState


# TODO: Things of the overall campaign, unlocks, etc.

var level:Level
var gameTime: float

var remainingDt: float

const TickStepDuration: float = 0.01


func _init() -> void:
	level = Level.new()



func update(dt:float) -> void:
	gameTime += dt
	
	remainingDt += dt
	while (remainingDt >= TickStepDuration):
		level.tick(TickStepDuration)
		remainingDt -= TickStepDuration

	level.update(dt)
