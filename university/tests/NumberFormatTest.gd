extends GdUnitTestSuite
## How counts and shares read in the UI. Inputs are arbitrary.


func test_counts_group_thousands() -> void:
	assert_str(NumberFormat.count(0)).is_equal("0")
	assert_str(NumberFormat.count(999)).is_equal("999")
	assert_str(NumberFormat.count(1080)).is_equal("1,080")
	assert_str(NumberFormat.count(1234567)).is_equal("1,234,567")
	assert_str(NumberFormat.count(-1080)).is_equal("−1,080")


func test_percentages_floor_to_whole_numbers() -> void:
	assert_str(NumberFormat.percent(0.333)).is_equal("33%")
	assert_str(NumberFormat.percent(1.11)).is_equal("111%")
	assert_str(NumberFormat.percent(0.0)).is_equal("0%")
	# 0.29 * 100 is 28.999999999999996 in floating point; it still reads 29%.
	assert_str(NumberFormat.percent(0.29)).is_equal("29%")
