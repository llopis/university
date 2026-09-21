class_name GameState
## The session: the campus and the clock that drives it. Time moves in fixed
## ticks; speed runs more of them per frame and pause runs none. Commands on
## the campus (building, destroying) are direct calls, so they work whether or
## not the clock is running.


# TODO: Things of the overall campaign, unlocks, etc.

const TickStepDuration: float = 0.01
## Running speeds the transport controls step through. Pausing is a separate
## control, so every entry here is a speed the sim actually runs at.
const SpeedSteps: Array[int] = [1, 3, 8]
# The most real time one frame may feed the clock, so a hitch cannot turn into
# a burst of thousands of ticks.
const MaxFrameDt: float = 0.1

var campus: Campus
var paused: bool = false
var speedIndex: int = 0
# Ticks run since the game began. Game time is derived from it, never accumulated.
var tickCount: int = 0

var remainingDt: float


func _init() -> void:
	campus = Campus.new()


func gameTime() -> float:
	return float(tickCount) * TickStepDuration


static func ticksPerMonth() -> int:
	return roundi(GameCalendar.SecondsPerMonth / TickStepDuration)


## Months since the game began (see GameCalendar).
func month() -> int:
	return floori(float(tickCount) / float(GameState.ticksPerMonth()))


func speedMultiplier() -> int:
	return SpeedSteps[speedIndex]


func changeSpeed(delta: int) -> void:
	setSpeedIndex(speedIndex + delta)


func setSpeedIndex(index: int) -> void:
	speedIndex = clampi(index, 0, SpeedSteps.size() - 1)


func togglePause() -> void:
	paused = not paused


## One tick of the sim. The one place the month rolls over into the campus.
func step() -> void:
	campus.tick(TickStepDuration)
	tickCount += 1
	if (month() != campus.month):
		campus.startMonth(month())


func update(dt: float) -> void:
	if (not paused):
		remainingDt += minf(dt, MaxFrameDt) * float(speedMultiplier())
		while (remainingDt >= TickStepDuration):
			step()
			remainingDt -= TickStepDuration
	campus.update(dt)


## Steps the sim to the start of the month that many months ahead, paused or
## not. For the console and tests.
func advanceMonths(months: int) -> void:
	var target: int = (month() + months) * GameState.ticksPerMonth()
	while (tickCount < target):
		step()
