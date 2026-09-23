extends GdUnitTestSuite
## Placement, destruction and picking rules. The fixture building type is
## arbitrary; assertions are about rules and relationships, not content.

const Diameter: float = 20.0
const QuarterTurn: float = PI / 2.0
const Overhead: float = 100.0
# Enough for any fixture building many times over.
const Funds: int = 100000000


## A campus with money to spend. Tests about money set their own balance.
func _campus() -> Campus:
	var campus: Campus = Campus.new(Finances.new())
	campus.finances.setCash(Funds)
	return campus


func _info() -> BuildingInfo:
	return BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter})


func test_place_on_empty_ground_adds_the_building() -> void:
	var campus: Campus = _campus()
	var building: Building = campus.place(_info(), Vector2.ZERO, 0.0)
	assert_object(building).is_not_null()
	assert_array(campus.buildings).contains_exactly([building])


func test_place_is_refused_on_overlap() -> void:
	var campus: Campus = _campus()
	campus.place(_info(), Vector2.ZERO, 0.0)
	assert_object(campus.place(_info(), Vector2(Diameter / 2.0, 0.0), 0.0)).is_null()
	assert_int(campus.buildings.size()).is_equal(1)


func test_rotation_decides_whether_a_neighbour_fits() -> void:
	var campus: Campus = _campus()
	campus.place(_info(), Vector2.ZERO, 0.0)
	# Beside the first along z with a gap: lying the same way it fits, turned
	# a quarter its long side reaches across the gap.
	var depth: float = Diameter * Building.DepthRatio
	var beside: Vector2 = Vector2(0.0, depth + 1.0)
	assert_bool(campus.canPlace(_info(), beside, 0.0)).is_true()
	assert_bool(campus.canPlace(_info(), beside, QuarterTurn)).is_false()


func test_place_is_refused_outside_the_bounds() -> void:
	var campus: Campus = _campus()
	var edge: Vector2 = Vector2(Campus.bounds().end.x, 0.0)
	assert_object(campus.place(_info(), edge, 0.0)).is_null()


func test_signals_carry_the_building() -> void:
	var campus: Campus = _campus()
	var added: Array[Building] = []
	var removed: Array[Building] = []
	campus.BuildingAdded.connect(func(b: Building) -> void: added.append(b))
	campus.BuildingRemoved.connect(func(b: Building) -> void: removed.append(b))
	var building: Building = campus.place(_info(), Vector2.ZERO, 0.0)
	campus.destroy(building)
	assert_array(added).contains_exactly([building])
	assert_array(removed).contains_exactly([building])


func test_a_refused_place_emits_nothing() -> void:
	var campus: Campus = _campus()
	campus.place(_info(), Vector2.ZERO, 0.0)
	var added: Array[Building] = []
	campus.BuildingAdded.connect(func(b: Building) -> void: added.append(b))
	campus.place(_info(), Vector2.ZERO, 0.0)
	assert_array(added).is_empty()


func test_destroy_frees_the_ground() -> void:
	var campus: Campus = _campus()
	var building: Building = campus.place(_info(), Vector2.ZERO, 0.0)
	campus.destroy(building)
	assert_array(campus.buildings).is_empty()
	assert_bool(campus.canPlace(_info(), Vector2.ZERO, 0.0)).is_true()


func test_destroying_a_building_not_on_the_campus_is_ignored() -> void:
	var campus: Campus = _campus()
	var removed: Array[Building] = []
	campus.BuildingRemoved.connect(func(b: Building) -> void: removed.append(b))
	campus.destroy(Building.new(_info(), Vector2.ZERO, 0.0))
	assert_array(removed).is_empty()


func test_pick_returns_the_building_under_the_ray() -> void:
	var campus: Campus = _campus()
	var building: Building = campus.place(_info(), Vector2(50.0, 50.0), 0.0)
	assert_object(campus.pick(Vector3(50.0, Overhead, 50.0), Vector3.DOWN)).is_same(building)
	assert_object(campus.pick(Vector3(-50.0, Overhead, -50.0), Vector3.DOWN)).is_null()


func test_pick_prefers_the_nearer_of_two_buildings_along_the_ray() -> void:
	var campus: Campus = _campus()
	var far: Building = campus.place(_info(), Vector2(100.0, 0.0), 0.0)
	var near: Building = campus.place(_info(), Vector2(50.0, 0.0), 0.0)
	var eyeHeight: float = Building.Height / 2.0
	assert_object(campus.pick(Vector3(0.0, eyeHeight, 0.0), Vector3.RIGHT)).is_same(near)
	assert_object(campus.pick(Vector3(200.0, eyeHeight, 0.0), Vector3.LEFT)).is_same(far)


const CostInM: int = 1


func _priced() -> BuildingInfo:
	return BuildingInfo.new({"id": "lab", "name": "Lab", "diameter": Diameter, "costM": CostInM})


func test_placing_spends_the_cost() -> void:
	var campus: Campus = _campus()
	var before: int = campus.finances.cash
	campus.place(_priced(), Vector2.ZERO, 0.0)
	assert_int(campus.finances.cash).is_equal(before - _priced().cost)


func test_a_building_that_cannot_be_paid_for_is_refused() -> void:
	var campus: Campus = _campus()
	campus.finances.setCash(_priced().cost - 1)
	assert_bool(campus.canPlace(_priced(), Vector2.ZERO, 0.0)).is_true()
	assert_bool(campus.canBuild(_priced(), Vector2.ZERO, 0.0)).is_false()
	assert_object(campus.place(_priced(), Vector2.ZERO, 0.0)).is_null()
	assert_int(campus.finances.cash).is_equal(_priced().cost - 1)


func test_exactly_enough_money_is_enough() -> void:
	var campus: Campus = _campus()
	campus.finances.setCash(_priced().cost)
	assert_object(campus.place(_priced(), Vector2.ZERO, 0.0)).is_not_null()
	assert_int(campus.finances.cash).is_equal(0)


func test_placing_announces_the_spend() -> void:
	var campus: Campus = _campus()
	var announced: Array[int] = []
	var onChanged: Callable = func() -> void: announced.append(campus.finances.cash)
	campus.finances.MoneyChanged.connect(onChanged)
	campus.place(_priced(), Vector2.ZERO, 0.0)
	# The listener holds the campus it was given, so let it go before asserting.
	campus.finances.MoneyChanged.disconnect(onChanged)
	assert_array(announced).contains_exactly([Funds - _priced().cost])


func test_a_new_building_is_under_construction_until_the_next_semester() -> void:
	var campus: Campus = _campus()
	var building: Building = campus.place(_priced(), Vector2.ZERO, 0.0)
	assert_bool(building.underConstruction).is_true()
	assert_int(building.opensAtMonth).is_equal(GameCalendar.nextSemesterStart(campus.month))


func test_a_building_opens_when_its_month_starts_and_not_before() -> void:
	var campus: Campus = _campus()
	var building: Building = campus.place(_priced(), Vector2.ZERO, 0.0)
	var opened: Array[Building] = []
	campus.BuildingOpened.connect(func(b: Building) -> void: opened.append(b))
	campus.startMonth(building.opensAtMonth - 1)
	assert_bool(building.underConstruction).is_true()
	campus.startMonth(building.opensAtMonth)
	assert_bool(building.underConstruction).is_false()
	campus.startMonth(building.opensAtMonth + 1)
	assert_array(opened).contains_exactly([building])


func test_a_building_placed_in_a_later_month_waits_for_the_semester_after_it() -> void:
	var campus: Campus = _campus()
	var firstSemester: int = GameCalendar.nextSemesterStart(0)
	campus.startMonth(firstSemester)
	var building: Building = campus.place(_priced(), Vector2.ZERO, 0.0)
	assert_int(building.opensAtMonth).is_equal(GameCalendar.nextSemesterStart(firstSemester))


func test_destroying_a_building_under_construction_refunds_it_in_full() -> void:
	var campus: Campus = _campus()
	var before: int = campus.finances.cash
	campus.destroy(campus.place(_priced(), Vector2.ZERO, 0.0))
	assert_int(campus.finances.cash).is_equal(before)


func test_a_listener_may_destroy_the_building_it_is_told_has_opened() -> void:
	var campus: Campus = _campus()
	var doomed: Building = campus.place(_priced(), Vector2.ZERO, 0.0)
	var survivor: Building = campus.place(_priced(), Vector2(Diameter * 2.0, 0.0), 0.0)
	var opened: Array[Building] = []
	var onOpened: Callable = func(b: Building) -> void:
		opened.append(b)
		if (b == doomed):
			campus.destroy(b)
	campus.BuildingOpened.connect(onOpened)
	campus.startMonth(doomed.opensAtMonth)
	# The listener holds the campus it was given, so let it go before asserting.
	campus.BuildingOpened.disconnect(onOpened)
	assert_array(opened).contains_exactly([doomed, survivor])
	assert_array(campus.buildings).contains_exactly([survivor])
	assert_bool(survivor.underConstruction).is_false()


func test_a_building_destroyed_before_its_turn_is_not_announced() -> void:
	var campus: Campus = _campus()
	var first: Building = campus.place(_priced(), Vector2.ZERO, 0.0)
	var second: Building = campus.place(_priced(), Vector2(Diameter * 2.0, 0.0), 0.0)
	var opened: Array[Building] = []
	var onOpened: Callable = func(b: Building) -> void:
		opened.append(b)
		if (b == first):
			campus.destroy(second)
	campus.BuildingOpened.connect(onOpened)
	campus.startMonth(first.opensAtMonth)
	# The listener holds the campus it was given, so let it go before asserting.
	campus.BuildingOpened.disconnect(onOpened)
	assert_array(opened).contains_exactly([first])
	assert_array(campus.buildings).contains_exactly([first])


func test_destroying_an_open_building_refunds_nothing() -> void:
	var campus: Campus = _campus()
	var building: Building = campus.place(_priced(), Vector2.ZERO, 0.0)
	var afterPaying: int = campus.finances.cash
	campus.startMonth(building.opensAtMonth)
	campus.destroy(building)
	assert_int(campus.finances.cash).is_equal(afterPaying)


const UpkeepInK: int = 3


func test_upkeep_counts_only_open_buildings() -> void:
	var campus: Campus = _campus()
	var info: BuildingInfo = BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter, "upkeepK": UpkeepInK})
	var first: Building = campus.place(info, Vector2.ZERO, 0.0)
	assert_int(campus.upkeep()).is_equal(0)
	campus.startMonth(first.opensAtMonth)
	campus.place(info, Vector2(Diameter * 2.0, 0.0), 0.0)
	assert_int(campus.upkeep()).is_equal(info.upkeep)


const Seats: int = 40
const Beds: int = 30
const Meals: int = 20


func test_capacities_count_only_open_buildings() -> void:
	var campus: Campus = _campus()
	var hall: BuildingInfo = BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter, "seats": Seats, "beds": Beds, "meals": Meals})
	var first: Building = campus.place(hall, Vector2.ZERO, 0.0)
	assert_int(campus.seats() + campus.beds() + campus.meals()).is_equal(0)
	campus.startMonth(first.opensAtMonth)
	campus.place(hall, Vector2(Diameter * 2.0, 0.0), 0.0)
	assert_int(campus.seats()).is_equal(Seats)
	assert_int(campus.beds()).is_equal(Beds)
	assert_int(campus.meals()).is_equal(Meals)


func test_only_an_open_admissions_office_counts() -> void:
	var campus: Campus = _campus()
	var office: BuildingInfo = BuildingInfo.new({"id": "office", "name": "Office", "diameter": Diameter, "admissionsOffice": true})
	var building: Building = campus.place(office, Vector2.ZERO, 0.0)
	assert_bool(campus.hasOpenAdmissionsOffice()).is_false()
	campus.startMonth(building.opensAtMonth)
	assert_bool(campus.hasOpenAdmissionsOffice()).is_true()


func test_a_month_start_answers_the_buildings_it_opened() -> void:
	var campus: Campus = _campus()
	var first: Building = campus.place(_info(), Vector2.ZERO, 0.0)
	var opened: Array[Building] = campus.startMonth(first.opensAtMonth)
	assert_array(opened).contains_exactly([first])
	assert_array(campus.startMonth(first.opensAtMonth + 1)).is_empty()


func test_buildings_opening_by_a_month_count_for_it() -> void:
	var campus: Campus = _campus()
	var hall: BuildingInfo = BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter, "seats": Seats, "admissionsOffice": true})
	var building: Building = campus.place(hall, Vector2.ZERO, 0.0)
	assert_int(campus.seats()).is_equal(0)
	assert_int(campus.seatsBy(building.opensAtMonth - 1)).is_equal(0)
	assert_int(campus.seatsBy(building.opensAtMonth)).is_equal(Seats)
	assert_bool(campus.hasAdmissionsOfficeBy(building.opensAtMonth)).is_true()
	assert_bool(campus.hasOpenAdmissionsOffice()).is_false()


func test_open_buildings_leave_out_those_under_construction() -> void:
	var campus: Campus = _campus()
	var first: Building = campus.place(_info(), Vector2.ZERO, 0.0)
	campus.startMonth(first.opensAtMonth)
	campus.place(_info(), Vector2(Diameter * 2.0, 0.0), 0.0)
	assert_array(campus.openBuildings()).contains_exactly([first])
