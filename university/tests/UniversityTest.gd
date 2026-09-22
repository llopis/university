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
