extends GdUnitTestSuite
## Prices set a year ahead and the minimum grade, and what applies without an
## Admissions Office. Prices are arbitrary fixtures.

const Tuition: int = 12000
const Room: int = 5000
const MealPlan: int = 4000
const Minimum: float = 3.2


func test_a_new_policy_charges_the_defaults() -> void:
	var policy: Policy = Policy.new()
	assert_int(policy.current.total()).is_equal(Policy.defaultPrices().total())
	assert_int(policy.next.total()).is_equal(Policy.defaultPrices().total())
	assert_float(policy.minimumGrade).is_equal(0.0)


func test_the_total_is_what_a_semester_costs() -> void:
	assert_int(Prices.new(Tuition, Room, MealPlan).total()).is_equal(Tuition + Room + MealPlan)


func test_prices_and_the_minimum_stay_in_range() -> void:
	var policy: Policy = Policy.new()
	policy.setNextTuition(-Tuition)
	policy.setNextRoom(-Room)
	policy.setNextMealPlan(-MealPlan)
	assert_int(policy.next.total()).is_equal(0)
	policy.setMinimumGrade(-Minimum)
	assert_float(policy.minimumGrade).is_equal(0.0)
	policy.setMinimumGrade(Minimum * 10.0)
	assert_float(policy.minimumGrade).is_less_equal(UniversityRules.MaxGrade)


func test_next_years_prices_apply_only_when_the_year_is_locked() -> void:
	var policy: Policy = Policy.new()
	policy.setNextTuition(Tuition)
	assert_int(policy.current.tuition).is_equal(Policy.DefaultTuition)
	policy.lockYear(true)
	assert_int(policy.current.tuition).is_equal(Tuition)
	# The year's prices are a copy: setting next year's again leaves them alone.
	policy.setNextTuition(Tuition * 2)
	assert_int(policy.current.tuition).is_equal(Tuition)


func test_without_an_admissions_office_the_defaults_apply_and_there_is_no_minimum() -> void:
	var policy: Policy = Policy.new()
	policy.setNextTuition(Tuition)
	policy.setMinimumGrade(Minimum)
	policy.lockYear(false)
	assert_int(policy.current.total()).is_equal(Policy.defaultPrices().total())
	assert_float(policy.minimumInUse(false)).is_equal(0.0)
	assert_float(policy.minimumInUse(true)).is_equal(Minimum)


func test_a_round_trip_keeps_the_policy() -> void:
	var policy: Policy = Policy.new()
	policy.setNextTuition(Tuition)
	policy.setMinimumGrade(Minimum)
	var back: Policy = Policy.fromDict(SaveFile.decode(SaveFile.encode(policy.toDict())) as Dictionary)
	assert_str(SaveFile.encode(back.toDict())).is_equal(SaveFile.encode(policy.toDict()))


func test_a_policy_missing_a_key_is_refused() -> void:
	var data: Dictionary = Policy.new().toDict()
	(data["next"] as Dictionary).erase("room")
	var loaded: Array[Policy] = []
	await assert_error(func() -> void: loaded.append(Policy.fromDict(data))) \
		.is_push_error(Variants.MissingKeysError % ["Prices", "room"])
	assert_object(loaded[0]).is_null()


func test_the_prices_for_next_fall_follow_the_office() -> void:
	var policy: Policy = Policy.new()
	policy.setNextTuition(Tuition)
	assert_int(policy.pricesFor(true).tuition).is_equal(Tuition)
	assert_int(policy.pricesFor(false).total()).is_equal(Policy.defaultPrices().total())
