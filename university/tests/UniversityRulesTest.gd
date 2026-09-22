extends GdUnitTestSuite
## The student loop's rules, as relationships: they hold whatever the tuning
## values are. Inputs are arbitrary fixtures built around the consts.

const Seats: int = 200
const HalfSeats: int = 100
const Reputation: float = 60.0
const Price: int = 18000
const Room: int = 9000
const MealPlan: int = 6000
const Enrolled: int = 1000
const HalfEnrolled: int = 500
const QuarterEnrolled: int = 250
# A dining load between recommended and the hard limit.
const Crowded: float = 1.2
const Epsilon: float = 0.0001


func test_applicants_rise_with_reputation() -> void:
	var better: int = UniversityRules.applicants(Reputation + UniversityRules.ReputationDoubling, Price)
	assert_int(better).is_greater(UniversityRules.applicants(Reputation, Price))


func test_applicants_fall_with_price_and_stay_finite_at_zero() -> void:
	var dearer: int = UniversityRules.applicants(Reputation, Price + roundi(UniversityRules.PriceHalving))
	assert_int(dearer).is_less(UniversityRules.applicants(Reputation, Price))
	assert_int(UniversityRules.applicants(Reputation, 0)).is_greater(0)


func test_as_many_applicants_as_seats_fills_them_at_the_base_grade() -> void:
	var intake: Intake = UniversityRules.admission(Seats, Seats, 0.0)
	assert_int(intake.admitted).is_equal(Seats)
	assert_float(intake.entryGrade).is_equal_approx(UniversityRules.GradeBase, Epsilon)


func test_more_applicants_fill_the_seats_with_a_higher_grade() -> void:
	var intake: Intake = UniversityRules.admission(Seats * 3, Seats, 0.0)
	assert_int(intake.admitted).is_equal(Seats)
	assert_float(intake.entryGrade).is_greater(UniversityRules.GradeBase)


func test_fewer_applicants_are_all_admitted_with_a_lower_grade() -> void:
	var intake: Intake = UniversityRules.admission(HalfSeats, Seats, 0.0)
	assert_int(intake.admitted).is_equal(HalfSeats)
	assert_float(intake.entryGrade).is_less(UniversityRules.GradeBase)


func test_a_minimum_above_the_cutoff_trades_students_for_grade() -> void:
	var open: Intake = UniversityRules.admission(Seats * 3, Seats, 0.0)
	var raised: float = open.entryGrade + UniversityRules.GradeSpread
	var picky: Intake = UniversityRules.admission(Seats * 3, Seats, raised)
	assert_int(picky.admitted).is_less(open.admitted)
	assert_float(picky.entryGrade).is_equal_approx(raised, Epsilon)
	# One below the cutoff changes nothing.
	var lenient: Intake = UniversityRules.admission(Seats * 3, Seats, open.entryGrade - UniversityRules.GradeSpread)
	assert_int(lenient.admitted).is_equal(open.admitted)
	assert_float(lenient.entryGrade).is_equal_approx(open.entryGrade, Epsilon)


func test_no_open_seats_admits_no_one() -> void:
	assert_int(UniversityRules.admission(Seats, 0, 0.0).admitted).is_equal(0)
	assert_int(UniversityRules.admission(0, Seats, 0.0).admitted).is_equal(0)


func test_housing_costs_satisfaction_only_past_the_threshold() -> void:
	var atThreshold: int = roundi(float(Enrolled) * (1.0 - UniversityRules.OverflowThreshold))
	var plentyOfMeals: int = Enrolled * 2
	assert_float(UniversityRules.satisfaction(Enrolled, atThreshold, plentyOfMeals).housing).is_equal_approx(0.0, Epsilon)
	var overflowing: Satisfaction = UniversityRules.satisfaction(Enrolled, atThreshold / 2, plentyOfMeals)
	assert_float(overflowing.housing).is_greater(0.0)
	assert_float(overflowing.total()).is_less(UniversityRules.SatisfactionBase)


func test_dining_crowds_past_its_recommended_load_and_starves_past_the_limit() -> void:
	var meals: int = HalfEnrolled
	var comfortable: Satisfaction = UniversityRules.satisfaction(Enrolled, meals, meals)
	assert_float(comfortable.crowding + comfortable.unfed).is_equal_approx(0.0, Epsilon)
	var crowded: Satisfaction = UniversityRules.satisfaction(Enrolled, roundi(float(meals) * Crowded), meals)
	assert_float(crowded.crowding).is_greater(0.0)
	assert_float(crowded.unfed).is_equal_approx(0.0, Epsilon)
	var atLimit: int = floori(UniversityRules.DiningHardLimit * float(meals))
	var starving: Satisfaction = UniversityRules.satisfaction(Enrolled, Enrolled, meals)
	assert_float(starving.unfed).is_greater(0.0)
	# Crowding stops growing at the limit: past it, the rest simply can't eat.
	var limited: Satisfaction = UniversityRules.satisfaction(Enrolled, atLimit, meals)
	assert_float(starving.crowding).is_equal_approx(limited.crowding, Epsilon)
	assert_int(UniversityRules.mealPlans(Enrolled, meals)).is_equal(atLimit)


func test_no_students_means_base_satisfaction() -> void:
	assert_float(UniversityRules.satisfaction(0, 0, 0).total()).is_equal_approx(UniversityRules.SatisfactionBase, Epsilon)


func test_reputation_moves_part_of_the_way_to_its_target_and_stays_in_range() -> void:
	var target: float = Reputation + 10.0
	var moved: float = UniversityRules.nextReputation(Reputation, target)
	assert_float(moved - Reputation).is_equal_approx(UniversityRules.ReputationRate * (target - Reputation), Epsilon)
	assert_float(UniversityRules.nextReputation(UniversityRules.MaxScore, UniversityRules.MaxScore * 3.0)).is_less_equal(UniversityRules.MaxScore)
	assert_float(UniversityRules.nextReputation(0.0, -UniversityRules.MaxScore)).is_greater_equal(0.0)


func test_the_grades_reputation_applicants_loop_settles_by_itself() -> void:
	# Once round the loop, an extra point of reputation must come back as less
	# than a point of target, or reputation runs away.
	assert_float(UniversityRules.loopGain()).is_less(1.0)


func test_off_campus_students_pay_tuition_only() -> void:
	var prices: Prices = Prices.new(Price, Room, MealPlan)
	var fees: Fees = UniversityRules.fees(prices, Enrolled, HalfEnrolled, QuarterEnrolled)
	assert_int(fees.tuition).is_equal(Price * Enrolled)
	assert_int(fees.room).is_equal(Room * HalfEnrolled)
	assert_int(fees.meals).is_equal(MealPlan * QuarterEnrolled)
	assert_int(fees.total()).is_equal(fees.tuition + fees.room + fees.meals)
