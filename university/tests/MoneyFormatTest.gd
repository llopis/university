extends GdUnitTestSuite
## How a dollar amount is abbreviated for the UI.


func test_millions_show_one_decimal() -> void:
	assert_str(MoneyFormat.short(10000000)).is_equal("$10.0M")
	assert_str(MoneyFormat.short(9300000)).is_equal("$9.3M")


func test_thousands_show_whole_k() -> void:
	assert_str(MoneyFormat.short(950000)).is_equal("$950K")


func test_small_amounts_show_dollars() -> void:
	assert_str(MoneyFormat.short(0)).is_equal("$0")
	assert_str(MoneyFormat.short(999)).is_equal("$999")


func test_the_boundary_belongs_to_the_larger_unit() -> void:
	assert_str(MoneyFormat.short(MoneyFormat.Million)).is_equal("$1.0M")
	assert_str(MoneyFormat.short(MoneyFormat.Thousand)).is_equal("$1K")


func test_an_abbreviated_balance_is_never_more_than_the_balance() -> void:
	assert_str(MoneyFormat.short(1960000)).is_equal("$1.9M")
	assert_str(MoneyFormat.short(999999)).is_equal("$999K")
	assert_str(MoneyFormat.short(1999)).is_equal("$1K")
