extends GdUnitTestSuite
## Saves on disk: JSON text that gives back exactly what was written, floats
## included.

const TestPath: String = "user://save_file_test.json"
const MissingPath: String = "user://no_such_save.json"
const NotASave: String = "[1, 2]"


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TestPath))


func test_floats_come_back_bit_identical() -> void:
	# Values with no short decimal form: any precision lost would show.
	var values: Array[float] = [PI / 7.0, 0.1 + 0.2, -123.456789012345678, 1.0e-17]
	var back: Dictionary = SaveFile.decode(SaveFile.encode({"values": values})) as Dictionary
	var backValues: Array = back["values"] as Array
	for i: int in range(values.size()):
		assert_float(Variants.toFloat(backValues[i])).is_equal(values[i])


func test_what_is_written_is_what_is_read() -> void:
	var data: Dictionary = {"name": "Somewhere", "count": 3, "nested": {"flag": true}}
	assert_bool(SaveFile.write(TestPath, data)).is_true()
	var back: Dictionary = SaveFile.read(TestPath) as Dictionary
	assert_str(str(back["name"])).is_equal("Somewhere")
	assert_int(Variants.toInt(back["count"])).is_equal(3)
	assert_bool(Variants.toBool((back["nested"] as Dictionary)["flag"])).is_true()


func test_reading_where_nothing_was_saved_gives_null() -> void:
	assert_that(SaveFile.read(MissingPath)).is_null()


func test_a_file_that_is_not_a_save_is_reported() -> void:
	var file: FileAccess = FileAccess.open(TestPath, FileAccess.WRITE)
	file.store_string(NotASave)
	file.close()
	var results: Array[Variant] = []
	await assert_error(func() -> void: results.append(SaveFile.read(TestPath))) \
		.is_push_error(SaveFile.NotASaveError % TestPath)
	assert_that(results[0]).is_null()
