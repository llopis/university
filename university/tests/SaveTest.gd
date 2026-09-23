extends GdUnitTestSuite
## Saving and loading: a round trip gives back the same game, and a loaded game
## plays out exactly as the saved one would have. Building types are fixtures.

const Diameter: float = 20.0
const Spacing: float = 40.0
# No short decimal form, so a save that lost precision would show.
const Angle: float = PI / 7.0
# _playedState ends right at month 12's fall start; this crosses the next one
# (month 24) and a month past it, so both games run a second fall after loading.
const MonthsAfterLoading: int = GameCalendar.MonthsPerYear + 1
const Name: String = "Test University"
# Non-default balances, so a save that forgot either would show.
const StartCash: int = 20000000
const Borrowed: int = 3000000
# Non-default loop state, so a save that forgot any of it would show.
const FirstClass: int = 30
const SecondClass: int = 25
const FirstGrade: float = 3.1
const SecondGrade: float = 2.9
const NextTuition: int = 9000
const Minimum: float = 2.5
const StartReputation: float = 61.5


func _db() -> BuildingInfoDB:
	var records: Array[Dictionary] = [
		{"id": "hall", "name": "Hall", "diameter": Diameter, "costM": 1, "upkeepK": 7, "beds": 20, "meals": 10, "admissionsOffice": true},
		{"id": "lab", "name": "Lab", "diameter": Diameter, "costM": 2, "upkeepK": 11, "seats": 60},
	]
	return BuildingInfoDB.new(records)


## A game some months in, played through a fall start: two buildings open
## (the hall's admissions office locked NextTuition into current, and the
## class was admitted into the lab's seats) and a third still under
## construction.
func _playedState(buildingDB: BuildingInfoDB) -> GameState:
	var state: GameState = GameState.new()
	state.university.name = Name
	state.university.finances.setCash(StartCash)
	state.university.finances.borrow(Borrowed)
	state.university.students.admit(FirstClass, FirstGrade)
	state.university.students.admit(SecondClass, SecondGrade)
	state.university.policy.setNextTuition(NextTuition)
	state.university.policy.setMinimumGrade(Minimum)
	state.university.reputation = StartReputation
	state.university.lastIntakeGrade = SecondGrade
	state.university.campus.place(buildingDB.info("hall"), Vector2.ZERO, Angle)
	state.advanceMonths(GameCalendar.nextSemesterStart(0))
	state.university.campus.place(buildingDB.info("lab"), Vector2(Spacing, Spacing), -Angle)
	var fallStart: int = GameCalendar.nextFallStart(state.university.campus.month)
	state.advanceMonths(fallStart - state.university.campus.month)
	var underConstruction: Building = state.university.campus.place(buildingDB.info("hall"), Vector2(-Spacing, -Spacing), Angle)
	assert_object(underConstruction).is_not_null()
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
	assert_int(loaded.university.finances.cash).is_equal(state.university.finances.cash)
	assert_int(loaded.university.finances.debt).is_equal(state.university.finances.debt)
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
	assert_int(buildings.size()).is_equal(2)
	assert_str(buildings[0].info.id).is_equal("hall")
	assert_str(buildings[1].info.id).is_equal("hall")


func test_a_save_missing_a_campus_key_is_refused() -> void:
	var buildingDB: BuildingInfoDB = _db()
	var data: Dictionary = _playedState(buildingDB).toDict()
	var campusData: Dictionary = (data["university"] as Dictionary)["campus"] as Dictionary
	campusData.erase("month")
	var loaded: Array[GameState] = []
	await assert_error(func() -> void: loaded.append(GameState.fromDict(data, buildingDB))) \
		.is_push_error(Variants.MissingKeysError % ["Campus", "month"])
	assert_object(loaded[0]).is_null()


func test_a_save_missing_a_finances_key_is_refused() -> void:
	var buildingDB: BuildingInfoDB = _db()
	var data: Dictionary = _playedState(buildingDB).toDict()
	var financesData: Dictionary = (data["university"] as Dictionary)["finances"] as Dictionary
	financesData.erase("cash")
	var loaded: Array[GameState] = []
	await assert_error(func() -> void: loaded.append(GameState.fromDict(data, buildingDB))) \
		.is_push_error(Variants.MissingKeysError % ["Finances", "cash"])
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


func test_a_save_missing_a_report_key_is_refused() -> void:
	var buildingDB: BuildingInfoDB = _db()
	var data: Dictionary = _playedState(buildingDB).toDict()
	var reportsData: Array = (data["university"] as Dictionary)["reports"] as Array
	(reportsData[0] as Dictionary).erase("applicants")
	var loaded: Array[GameState] = []
	await assert_error(func() -> void: loaded.append(GameState.fromDict(data, buildingDB))) \
		.is_push_error(Variants.MissingKeysError % ["SemesterReport", "applicants"])
	assert_object(loaded[0]).is_null()


func test_pause_and_speed_are_not_saved() -> void:
	var buildingDB: BuildingInfoDB = _db()
	var state: GameState = _playedState(buildingDB)
	state.setPaused(true)
	state.setSpeedIndex(GameState.SpeedSteps.size() - 1)
	var loaded: GameState = _reloaded(state, buildingDB)
	assert_bool(loaded.paused).is_false()
	assert_int(loaded.speedIndex).is_equal(0)


func test_a_loaded_campus_spends_from_the_loaded_finances() -> void:
	var buildingDB: BuildingInfoDB = _db()
	var loaded: GameState = _reloaded(_playedState(buildingDB), buildingDB)
	assert_object(loaded.university.campus.finances).is_same(loaded.university.finances)


func test_a_save_missing_a_students_key_is_refused() -> void:
	var buildingDB: BuildingInfoDB = _db()
	var data: Dictionary = _playedState(buildingDB).toDict()
	((data["university"] as Dictionary)["students"] as Dictionary).erase("cohorts")
	var loaded: Array[GameState] = []
	await assert_error(func() -> void: loaded.append(GameState.fromDict(data, buildingDB))) \
		.is_push_error(Variants.MissingKeysError % ["StudentBody", "cohorts"])
	assert_object(loaded[0]).is_null()


func test_a_save_missing_a_policy_key_is_refused() -> void:
	var buildingDB: BuildingInfoDB = _db()
	var data: Dictionary = _playedState(buildingDB).toDict()
	((data["university"] as Dictionary)["policy"] as Dictionary).erase("next")
	var loaded: Array[GameState] = []
	await assert_error(func() -> void: loaded.append(GameState.fromDict(data, buildingDB))) \
		.is_push_error(Variants.MissingKeysError % ["Policy", "next"])
	assert_object(loaded[0]).is_null()
