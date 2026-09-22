extends GdUnitTestSuite
## Saving and loading: a round trip gives back the same game, and a loaded game
## plays out exactly as the saved one would have. Building types are fixtures.

const Diameter: float = 20.0
const Spacing: float = 40.0
# No short decimal form, so a save that lost precision would show.
const Angle: float = PI / 7.0
const MonthsAfterLoading: int = 7
const Name: String = "Test University"


func _db() -> BuildingInfoDB:
	var records: Array[Dictionary] = [
		{"id": "hall", "name": "Hall", "diameter": Diameter, "costM": 1},
		{"id": "lab", "name": "Lab", "diameter": Diameter, "costM": 2},
	]
	return BuildingInfoDB.new(records)


## A game some months in: one building open, one still under construction.
func _playedState(buildingDB: BuildingInfoDB) -> GameState:
	var state: GameState = GameState.new()
	state.university.name = Name
	state.university.campus.place(buildingDB.info("hall"), Vector2.ZERO, Angle)
	state.advanceMonths(GameCalendar.nextSemesterStart(0))
	state.university.campus.place(buildingDB.info("lab"), Vector2(Spacing, Spacing), -Angle)
	state.advanceMonths(1)
	return state


## Through the same text a save file holds.
func _reloaded(state: GameState, buildingDB: BuildingInfoDB) -> GameState:
	var data: Dictionary = SaveFile.decode(SaveFile.encode(state.toDict())) as Dictionary
	return GameState.fromDict(data, buildingDB)


func test_a_round_trip_gives_back_the_same_game() -> void:
	var buildingDB: BuildingInfoDB = _db()
	var state: GameState = _playedState(buildingDB)
	var saved: String = SaveFile.encode(state.toDict())
	assert_str(SaveFile.encode(_reloaded(state, buildingDB).toDict())).is_equal(saved)


func test_a_loaded_game_plays_out_as_the_saved_one_would_have() -> void:
	# The lab opens during the months played after loading, in both games.
	var buildingDB: BuildingInfoDB = _db()
	var original: GameState = _playedState(buildingDB)
	var loaded: GameState = _reloaded(original, buildingDB)
	original.advanceMonths(MonthsAfterLoading)
	loaded.advanceMonths(MonthsAfterLoading)
	assert_str(SaveFile.encode(loaded.toDict())).is_equal(SaveFile.encode(original.toDict()))


func test_loading_restores_the_campus_as_it_was() -> void:
	var buildingDB: BuildingInfoDB = _db()
	var state: GameState = _playedState(buildingDB)
	var loaded: GameState = _reloaded(state, buildingDB)
	var campus: Campus = state.university.campus
	var back: Campus = loaded.university.campus
	assert_str(loaded.university.name).is_equal(Name)
	assert_int(loaded.tickCount).is_equal(state.tickCount)
	assert_int(back.month).is_equal(campus.month)
	assert_int(back.money).is_equal(campus.money)
	assert_int(back.buildings.size()).is_equal(campus.buildings.size())
	for i: int in range(campus.buildings.size()):
		var was: Building = campus.buildings[i]
		var now: Building = back.buildings[i]
		assert_object(now.info).is_same(was.info)
		assert_vector(now.pos).is_equal(was.pos)
		assert_float(now.angle).is_equal(was.angle)
		assert_bool(now.underConstruction).is_equal(was.underConstruction)
		assert_int(now.opensAtMonth).is_equal(was.opensAtMonth)


func test_a_building_whose_type_is_gone_is_left_out_and_reported() -> void:
	var data: Dictionary = _playedState(_db()).toDict()
	var records: Array[Dictionary] = [{"id": "hall", "name": "Hall", "diameter": Diameter}]
	var withoutLab: BuildingInfoDB = BuildingInfoDB.new(records)
	var loaded: Array[GameState] = []
	await assert_error(func() -> void: loaded.append(GameState.fromDict(data, withoutLab))) \
		.is_push_error(Campus.UnknownTypeError % "lab")
	var buildings: Array[Building] = loaded[0].university.campus.buildings
	assert_int(buildings.size()).is_equal(1)
	assert_str(buildings[0].info.id).is_equal("hall")


func test_a_save_missing_a_campus_key_is_refused() -> void:
	var buildingDB: BuildingInfoDB = _db()
	var data: Dictionary = _playedState(buildingDB).toDict()
	var campusData: Dictionary = (data["university"] as Dictionary)["campus"] as Dictionary
	campusData.erase("money")
	var loaded: Array[GameState] = []
	await assert_error(func() -> void: loaded.append(GameState.fromDict(data, buildingDB))) \
		.is_push_error(Variants.MissingKeysError % ["Campus", "money"])
	assert_object(loaded[0]).is_null()


func test_a_save_missing_a_building_key_is_refused() -> void:
	var buildingDB: BuildingInfoDB = _db()
	var data: Dictionary = _playedState(buildingDB).toDict()
	var campusData: Dictionary = (data["university"] as Dictionary)["campus"] as Dictionary
	var buildingsData: Array = campusData["buildings"] as Array
	(buildingsData[0] as Dictionary).erase("pos")
	var loaded: Array[GameState] = []
	await assert_error(func() -> void: loaded.append(GameState.fromDict(data, buildingDB))) \
		.is_push_error(Variants.MissingKeysError % ["Campus building", "pos"])
	assert_object(loaded[0]).is_null()


func test_pause_and_speed_are_not_saved() -> void:
	var buildingDB: BuildingInfoDB = _db()
	var state: GameState = _playedState(buildingDB)
	state.setPaused(true)
	state.setSpeedIndex(GameState.SpeedSteps.size() - 1)
	var loaded: GameState = _reloaded(state, buildingDB)
	assert_bool(loaded.paused).is_false()
	assert_int(loaded.speedIndex).is_equal(0)
