class_name GameState
## The session: the university and the clock that drives it. Time moves in fixed
## ticks; speed runs more of them per frame and pause runs none. Commands on
## the campus (building, destroying) are direct calls, so they work whether or
## not the clock is running.


# TODO: Things of the overall campaign, unlocks, etc.

const TickStepDuration: float = 0.01
# Ticks in one month: the one place a month's length becomes ticks.
const TicksPerMonth: int = int(GameCalendar.SecondsPerMonth / TickStepDuration)
## Running speeds the transport controls step through. Pausing is a separate
## control, so every entry here is a speed the sim actually runs at.
const SpeedSteps: Array[int] = [1, 3, 8]
# The most real time one frame may feed the clock, so a hitch cannot turn into
# a burst of thousands of ticks.
const MaxFrameDt: float = 0.1

var university: University
var paused: bool = false
var speedIndex: int = 0
# Ticks run since the game began. Game time is derived from it, never accumulated.
var tickCount: int = 0

var remainingDt: float


func _init() -> void:
	university = University.new()


func gameTime() -> float:
	return float(tickCount) * TickStepDuration


## Months since the game began (see GameCalendar).
func month() -> int:
	return floori(float(tickCount) / float(TicksPerMonth))


func speedMultiplier() -> int:
	return SpeedSteps[speedIndex]


func changeSpeed(delta: int) -> void:
	setSpeedIndex(speedIndex + delta)


func setSpeedIndex(index: int) -> void:
	speedIndex = clampi(index, 0, SpeedSteps.size() - 1)


## The one writer of `paused`.
func setPaused(value: bool) -> void:
	paused = value


func togglePause() -> void:
	setPaused(not paused)


## What a transport speed button means: run, at that speed. The keys and the
## console move the speed with setSpeedIndex/changeSpeed and leave pause alone.
func runAt(index: int) -> void:
	setPaused(false)
	setSpeedIndex(index)


## One tick of the sim. The one place the month rolls over into the university.
func step() -> void:
	university.campus.tick(TickStepDuration)
	tickCount += 1
	if (month() != university.campus.month):
		university.startMonth(month())


func update(dt: float) -> void:
	if (not paused):
		remainingDt += minf(dt, MaxFrameDt) * float(speedMultiplier())
		while (remainingDt >= TickStepDuration):
			step()
			remainingDt -= TickStepDuration
	university.campus.update(dt)


## Steps the sim to the start of the month that many months ahead, paused or
## not. For the console and tests.
func advanceMonths(months: int) -> void:
	var target: int = (month() + months) * TicksPerMonth
	while (tickCount < target):
		step()


# Keys toDict writes; fromDict refuses a dictionary missing any of them.
const SavedKeys: Array[String] = ["tickCount", "university"]


## The clock is saved as its tick count. Speed, pause and the partial tick in
## `remainingDt` belong to the session, so a loaded game starts the way a new
## one does.
func toDict() -> Dictionary:
	return {"tickCount": tickCount, "university": university.toDict()}


## Null when data is missing a key, or its university refused.
static func fromDict(data: Dictionary, buildingDB: BuildingInfoDB) -> GameState:
	if (not Variants.hasKeys(data, SavedKeys, "GameState")):
		return null
	var loadedUniversity: University = University.fromDict(data["university"] as Dictionary, buildingDB)
	if (loadedUniversity == null):
		return null
	var state: GameState = GameState.new()
	state.tickCount = Variants.toInt(data["tickCount"])
	state.university = loadedUniversity
	return state
