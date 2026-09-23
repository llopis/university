extends GdUnitTestSuite
## How building types are worded. Fixtures are arbitrary.

const Diameter: float = 40.0
const Seats: int = 400


func test_a_type_holds_and_adds_its_capacity() -> void:
	var hall: BuildingInfo = BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter, "seats": Seats})
	assert_str(BuildingText.holds(hall)).contains(NumberFormat.count(Seats))
	assert_str(BuildingText.adds(hall)).starts_with("+")
	assert_str(BuildingText.adds(hall)).contains(NumberFormat.count(Seats))
	var bare: BuildingInfo = BuildingInfo.new({"id": "bare", "name": "Bare", "diameter": Diameter})
	assert_str(BuildingText.adds(bare)).is_empty()


func test_the_footprint_is_the_placed_box() -> void:
	var hall: BuildingInfo = BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter})
	var box: Vector2 = Building.rectFor(hall, Vector2.ZERO, 0.0).size
	assert_str(BuildingText.footprint(hall)).is_equal(BuildingText.FootprintFormat % [roundi(box.x), roundi(box.y)])
