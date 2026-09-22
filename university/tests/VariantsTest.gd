extends GdUnitTestSuite
## Reading typed values out of parsed data: JSON gives every number back as a
## float, and a blank CSV cell arrives as "".

const Epsilon: float = 0.0001


func test_a_whole_float_reads_as_the_same_int() -> void:
	assert_int(Variants.toInt(50000000.0)).is_equal(50000000)
	assert_int(Variants.toInt(-3.0)).is_equal(-3)


func test_an_int_reads_as_itself_either_way() -> void:
	assert_int(Variants.toInt(7)).is_equal(7)
	assert_float(Variants.toFloat(7)).is_equal_approx(7.0, Epsilon)


func test_anything_that_is_not_a_number_reads_as_zero() -> void:
	assert_int(Variants.toInt("")).is_equal(0)
	assert_float(Variants.toFloat("")).is_equal_approx(0.0, Epsilon)
	assert_int(Variants.toInt(null)).is_equal(0)


func test_only_a_true_bool_reads_as_true() -> void:
	assert_bool(Variants.toBool(true)).is_true()
	assert_bool(Variants.toBool(false)).is_false()
	assert_bool(Variants.toBool("")).is_false()
	assert_bool(Variants.toBool(null)).is_false()
