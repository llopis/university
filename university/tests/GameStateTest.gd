extends GdUnitTestSuite
## The clock: ticks, speed, pause and the month rolling over into the campus.

const Frame: float = 0.05
const Epsilon: float = 0.0001
const Diameter: float = 20.0


func _info() -> BuildingInfo:
	return BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter})


func test_time_passes_while_running() -> void:
	var state: GameState = GameState.new()
	state.update(Frame)
	assert_int(state.tickCount).is_greater(0)


func test_no_time_passes_while_paused() -> void:
	var state: GameState = GameState.new()
	state.togglePause()
	state.update(Frame)
	assert_int(state.tickCount).is_equal(0)
	state.togglePause()
	state.update(Frame)
	assert_int(state.tickCount).is_greater(0)


func test_game_time_is_the_tick_count_times_the_step() -> void:
	var state: GameState = GameState.new()
	state.step()
	state.step()
	assert_float(state.gameTime()).is_equal_approx(2.0 * GameState.TickStepDuration, Epsilon)


func test_a_faster_speed_runs_that_many_times_the_ticks() -> void:
	var slow: GameState = GameState.new()
	slow.update(Frame)
	var fast: GameState = GameState.new()
	fast.setSpeedIndex(GameState.SpeedSteps.size() - 1)
	fast.update(Frame)
	var multiplier: int = fast.speedMultiplier()
	# Within one multiplier's worth: the accumulator may hold back a partial tick.
	assert_int(absi(fast.tickCount - slow.tickCount * multiplier)).is_less_equal(multiplier)


func test_speed_stays_within_its_steps() -> void:
	var state: GameState = GameState.new()
	state.changeSpeed(-1)
	assert_int(state.speedIndex).is_equal(0)
	state.changeSpeed(GameState.SpeedSteps.size() * 2)
	assert_int(state.speedIndex).is_equal(GameState.SpeedSteps.size() - 1)
	state.setSpeedIndex(-5)
	assert_int(state.speedIndex).is_equal(0)


func test_a_long_frame_is_capped() -> void:
	var state: GameState = GameState.new()
	state.update(GameState.MaxFrameDt * 50.0)
	assert_float(state.gameTime()).is_less_equal(GameState.MaxFrameDt + GameState.TickStepDuration)


func test_the_frame_cap_is_applied_before_the_speed_multiplier() -> void:
	var state: GameState = GameState.new()
	state.setSpeedIndex(GameState.SpeedSteps.size() - 1)
	state.update(GameState.MaxFrameDt * 50.0)
	# The cap bounds the real time a frame may feed the clock, so the hitch
	# costs at most the cap times the multiplier — not the multiplier times a
	# whole hitch, which capping afterwards would allow.
	var multiplier: float = float(state.speedMultiplier())
	assert_float(state.gameTime()).is_less_equal(
		GameState.MaxFrameDt * multiplier + GameState.TickStepDuration)
	assert_float(state.gameTime()).is_greater(GameState.MaxFrameDt)


func test_months_roll_over_into_the_campus_and_open_buildings() -> void:
	var state: GameState = GameState.new()
	var building: Building = state.campus.place(_info(), Vector2.ZERO, 0.0)
	state.advanceMonths(building.opensAtMonth - 1)
	assert_int(state.month()).is_equal(building.opensAtMonth - 1)
	assert_int(state.campus.month).is_equal(state.month())
	assert_bool(building.underConstruction).is_true()
	state.advanceMonths(1)
	assert_bool(building.underConstruction).is_false()


func test_run_at_unpauses_and_picks_the_speed() -> void:
	var state: GameState = GameState.new()
	state.setPaused(true)
	var top: int = GameState.SpeedSteps.size() - 1
	state.runAt(top)
	assert_bool(state.paused).is_false()
	assert_int(state.speedIndex).is_equal(top)
	state.setPaused(true)
	state.runAt(top * 2)
	assert_bool(state.paused).is_false()
	assert_int(state.speedIndex).is_equal(top)


func test_setting_paused_twice_leaves_it_paused() -> void:
	var state: GameState = GameState.new()
	state.setPaused(true)
	state.setPaused(true)
	assert_bool(state.paused).is_true()
	state.update(Frame)
	assert_int(state.tickCount).is_equal(0)


func test_changing_speed_leaves_pause_alone() -> void:
	var state: GameState = GameState.new()
	state.setPaused(true)
	state.setSpeedIndex(GameState.SpeedSteps.size() - 1)
	state.changeSpeed(-1)
	assert_bool(state.paused).is_true()


func test_advancing_months_works_while_paused() -> void:
	var state: GameState = GameState.new()
	state.setPaused(true)
	var building: Building = state.campus.place(_info(), Vector2.ZERO, 0.0)
	state.advanceMonths(building.opensAtMonth)
	assert_int(state.month()).is_equal(building.opensAtMonth)
	assert_bool(building.underConstruction).is_false()
	assert_bool(state.paused).is_true()


func test_building_works_while_paused() -> void:
	var state: GameState = GameState.new()
	state.togglePause()
	var building: Building = state.campus.place(_info(), Vector2.ZERO, 0.0)
	assert_object(building).is_not_null()
	state.campus.destroy(building)
	assert_array(state.campus.buildings).is_empty()
