extends GdUnitTestSuite
## The university hands each new month on to its campus.

const Diameter: float = 20.0


func test_a_new_month_reaches_the_campus() -> void:
	var university: University = University.new()
	var info: BuildingInfo = BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter})
	var building: Building = university.campus.place(info, Vector2.ZERO, 0.0)
	university.startMonth(building.opensAtMonth)
	assert_int(university.campus.month).is_equal(building.opensAtMonth)
	assert_bool(building.underConstruction).is_false()


func test_the_campus_spends_from_the_university_finances() -> void:
	var university: University = University.new()
	assert_object(university.campus.finances).is_same(university.finances)


const UpkeepInK: int = 5
const Cash: int = 10000000
const Debt: int = 2000000


func _upkept() -> BuildingInfo:
	return BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter, "upkeepK": UpkeepInK})


func test_each_month_charges_open_upkeep_and_interest() -> void:
	var university: University = University.new()
	university.finances.setCash(Cash)
	university.finances.borrow(Debt)
	var building: Building = university.campus.place(_upkept(), Vector2.ZERO, 0.0)
	var before: int = university.finances.cash
	var interest: int = university.finances.interest()
	# The building opens at this month's start, so this month's bill has its upkeep.
	university.startMonth(building.opensAtMonth)
	assert_int(university.finances.cash).is_equal(before - _upkept().upkeep - interest)


func test_a_bill_past_the_cash_is_borrowed() -> void:
	var university: University = University.new()
	var building: Building = university.campus.place(_upkept(), Vector2.ZERO, 0.0)
	university.startMonth(building.opensAtMonth)
	var upkeep: int = _upkept().upkeep
	assert_int(university.finances.cash).is_equal(0)
	assert_int(university.finances.debt).is_equal(upkeep + roundi(float(upkeep) * Finances.ShortfallFee))
