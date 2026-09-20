class_name GameState


# TODO: Things of the overall campaign, unlocks, etc.

var campus: Campus
var gameTime: float

var remainingDt: float

const TickStepDuration: float = 0.01


func _init() -> void:
	campus = Campus.new()


func update(dt: float) -> void:
	gameTime += dt

	remainingDt += dt
	while (remainingDt >= TickStepDuration):
		campus.tick(TickStepDuration)
		remainingDt -= TickStepDuration

	campus.update(dt)
