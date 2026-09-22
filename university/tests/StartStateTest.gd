extends GdUnitTestSuite
## The shipped start state: it loads against the shipped building data, and
## every building in it stands where the placement rules allow. Nothing here
## asserts what the start state contains.


func _startData() -> Dictionary:
	return SaveFile.read(Global.StartStatePath) as Dictionary


func _startState() -> GameState:
	return GameState.fromDict(_startData(), Global.buildingDB)


func test_the_start_state_loads_every_building_it_lists() -> void:
	var campusData: Dictionary = (_startData()["university"] as Dictionary)["campus"] as Dictionary
	var listed: Array = campusData["buildings"] as Array
	assert_int(listed.size()).is_greater(0)
	assert_int(_startState().university.campus.buildings.size()).is_equal(listed.size())


func test_every_start_building_stands_where_it_could_be_placed() -> void:
	# Set down one by one on an empty campus: each must be inside the bounds and
	# clear of the ones before it, so a hand edit cannot sneak in an overlap.
	var check: Campus = Campus.new()
	for building: Building in _startState().university.campus.buildings:
		assert_bool(check.canPlace(building.info, building.pos, building.angle)).is_true()
		check.buildings.append(building)


func test_the_saved_month_matches_the_tick_count() -> void:
	# Two sources of the same month: a mismatch would make the first tick run
	# a spurious month start.
	var state: GameState = _startState()
	assert_int(state.university.campus.month).is_equal(state.month())
