extends GdUnitTestSuite
## Parsing and lookup of building definitions. Fixtures are arbitrary records;
## nothing here asserts what the real data file holds.

const FixturePath: String = "res://tests/fixtures/buildings_fixture.txt"
const Epsilon: float = 0.0001


func _records() -> Array[Dictionary]:
	var records: Array[Dictionary] = [
		{"id": "first", "name": "First", "category": "Cat", "costM": "", "buildTime": "", "diameter": 12},
		{"id": "second", "name": "Second", "category": "Cat", "costM": 1.5, "buildTime": 2.5, "diameter": 7.5},
	]
	return records


func test_blank_numeric_cells_coerce_to_zero() -> void:
	var info: BuildingInfo = BuildingInfo.new(_records()[0])
	assert_int(info.cost).is_equal(0)
	assert_float(info.buildTime).is_equal_approx(0.0, Epsilon)


func test_int_cell_is_read_as_float_diameter() -> void:
	var info: BuildingInfo = BuildingInfo.new(_records()[0])
	assert_float(info.diameter).is_equal_approx(12.0, Epsilon)


func test_missing_optional_columns_default() -> void:
	var info: BuildingInfo = BuildingInfo.new({"id": "bare", "name": "Bare"})
	assert_str(info.category).is_equal("")
	assert_float(info.diameter).is_equal_approx(0.0, Epsilon)


func test_lookup_by_id() -> void:
	var buildingDB: BuildingInfoDB = BuildingInfoDB.new(_records())
	assert_str(buildingDB.info("second").name).is_equal("Second")
	assert_object(buildingDB.info("nope")).is_null()


func test_all_keeps_record_order() -> void:
	var buildingDB: BuildingInfoDB = BuildingInfoDB.new(_records())
	assert_int(buildingDB.all.size()).is_equal(2)
	assert_str(buildingDB.all[0].id).is_equal("first")
	assert_str(buildingDB.all[1].id).is_equal("second")


func test_a_record_without_a_usable_diameter_is_left_out() -> void:
	# A zero-size footprint would place a building nothing can pick or overlap,
	# so the record is reported and dropped rather than half-loaded.
	var records: Array[Dictionary] = _records()
	records.append({"id": "sizeless", "name": "Sizeless", "category": "Cat", "diameter": ""})
	var loaded: Array[BuildingInfoDB] = []
	await assert_error(func() -> void: loaded.append(BuildingInfoDB.new(records))) \
		.is_push_error(BuildingInfoDB.NoDiameterError % "sizeless")
	var buildingDB: BuildingInfoDB = loaded[0]
	assert_object(buildingDB.info("sizeless")).is_null()
	assert_int(buildingDB.all.size()).is_equal(2)
	assert_str(buildingDB.all[0].id).is_equal("first")


func test_load_from_file_parses_rows_and_blanks() -> void:
	var buildingDB: BuildingInfoDB = BuildingInfoDB.loadFrom(FixturePath)
	assert_int(buildingDB.all.size()).is_equal(2)
	assert_int(buildingDB.info("alpha").cost).is_equal(0)
	assert_int(buildingDB.info("beta").cost).is_equal(roundi(1.5 * BuildingInfo.DollarsPerM))
	assert_float(buildingDB.info("beta").diameter).is_equal_approx(7.5, Epsilon)


func test_cost_is_read_in_millions_and_held_in_dollars() -> void:
	var info: BuildingInfo = BuildingInfo.new(_records()[1])
	assert_int(info.cost).is_equal(roundi(1.5 * BuildingInfo.DollarsPerM))


func test_a_whole_number_of_millions_reads_the_same_way() -> void:
	var info: BuildingInfo = BuildingInfo.new({"id": "big", "name": "Big", "diameter": 5, "costM": 2})
	assert_int(info.cost).is_equal(2 * BuildingInfo.DollarsPerM)


func test_a_negative_cost_reads_as_free() -> void:
	var info: BuildingInfo = BuildingInfo.new({"id": "odd", "name": "Odd", "diameter": 5, "costM": -20})
	assert_int(info.cost).is_equal(0)
