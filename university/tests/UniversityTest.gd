extends GdUnitTestSuite
## The university hands each new month on to its campus.

const Diameter: float = 20.0
const Epsilon: float = 0.0001


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


const HallSeats: int = 100
const HallBeds: int = 60
const HallMeals: int = 80
# Upkeep, so the monthly bill is never zero: a zero bill cannot show what it
# was paid from.
const HallUpkeepK: int = 100
const Students: int = 50
const Grade: float = 3.0


func _hall() -> BuildingInfo:
	return BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter, "seats": HallSeats, "beds": HallBeds, "meals": HallMeals, "upkeepK": HallUpkeepK})


## A university with an open hall, a first cohort and money, just after the
## spring start at which the hall opened.
func _running() -> University:
	var university: University = University.new()
	university.finances.setCash(Cash)
	var building: Building = university.campus.place(_hall(), Vector2.ZERO, 0.0)
	university.students.admit(Students, Grade)
	university.startMonth(building.opensAtMonth)
	return university


## The latest semester report. Indexed, not back(): back() answers an untyped
## Variant, and reading a field off one is an error in this project.
func _last(university: University) -> SemesterReport:
	return university.reports[university.reports.size() - 1]


func test_admission_happens_only_at_a_fall_start() -> void:
	var university: University = _running()
	# _running() ended on a spring start: one cohort, the one it began with.
	assert_int(university.students.cohorts.size()).is_equal(1)
	university.startMonth(GameCalendar.nextFallStart(university.campus.month))
	assert_int(university.students.cohorts.size()).is_equal(2)
	assert_bool(_last(university).isFall).is_true()
	assert_int(_last(university).admitted).is_greater(0)


func test_fees_arrive_before_that_months_bill() -> void:
	var university: University = _running()
	# Cash below the bill: were the bill charged first, it would borrow.
	university.finances.setCash(0)
	var borrowed: Array[int] = []
	university.finances.AutoBorrowed.connect(func(drawn: int, _charged: int) -> void: borrowed.append(drawn))
	var bill: int = university.monthlyExpenses()
	university.startMonth(GameCalendar.nextFallStart(university.campus.month))
	var report: SemesterReport = _last(university)
	assert_array(borrowed).is_empty()
	assert_int(university.finances.cash).is_equal(report.totalFees() - bill)


func test_overflow_students_pay_tuition_only() -> void:
	var university: University = University.new()
	var building: Building = university.campus.place(_hall(), Vector2.ZERO, 0.0)
	university.students.admit(HallBeds * 2, Grade)
	university.startMonth(building.opensAtMonth)
	var report: SemesterReport = _last(university)
	assert_int(report.housed).is_equal(HallBeds)
	assert_int(report.roomFees).is_equal(university.policy.current.room * HallBeds)
	assert_int(report.tuitionFees).is_equal(university.policy.current.tuition * HallBeds * 2)


func test_a_building_opening_at_a_semester_start_counts_that_semester() -> void:
	var university: University = University.new()
	var building: Building = university.campus.place(_hall(), Vector2.ZERO, 0.0)
	university.students.admit(Students, Grade)
	university.startMonth(building.opensAtMonth)
	var report: SemesterReport = _last(university)
	assert_int(report.beds).is_equal(HallBeds)
	assert_int(report.housed).is_equal(Students)
	assert_array(report.opened).contains_exactly([_hall().name])


func test_a_cohort_graduates_after_eight_semesters_and_is_reported() -> void:
	var university: University = _running()
	university.students.cohorts[0].semestersCompleted = StudentBody.SemestersToGraduate - 1
	university.startMonth(GameCalendar.nextFallStart(university.campus.month))
	assert_int(_last(university).graduated).is_equal(Students)


func test_reputation_steps_toward_its_target_only_at_a_fall_start() -> void:
	var university: University = _running()
	var before: float = university.reputation
	var target: float = university.reputationTarget()
	university.startMonth(university.campus.month + 1)
	assert_float(university.reputation).is_equal(before)
	university.startMonth(GameCalendar.nextFallStart(university.campus.month))
	assert_float(university.reputation).is_equal_approx(UniversityRules.nextReputation(before, target), Epsilon)


func test_the_first_reports_satisfaction_change_is_measured_from_the_last_sample() -> void:
	var university: University = University.new()
	university.students.admit(HallBeds * 2, Grade)
	var building: Building = university.campus.place(_hall(), Vector2.ZERO, 0.0)
	# The dorm is still under construction: no beds yet, so this is the same
	# "before" state a real sample would have caught at the previous start.
	var sample: float = university.satisfactionNow().total()
	university.satisfactionSamples.append(sample)
	university.startMonth(building.opensAtMonth)
	var report: SemesterReport = _last(university)
	assert_float(report.satisfactionChange).is_equal_approx(report.satisfaction - sample, Epsilon)
	assert_float(report.satisfactionChange).is_not_zero()


func test_the_falls_report_measures_the_reputation_change() -> void:
	var university: University = _running()
	var before: float = university.reputation
	university.startMonth(GameCalendar.nextFallStart(university.campus.month))
	var report: SemesterReport = _last(university)
	assert_float(report.reputationChange).is_equal_approx(report.reputation - before, Epsilon)


func test_setReputation_clamps_both_ends() -> void:
	var university: University = University.new()
	university.setReputation(UniversityRules.MaxScore + 10.0)
	assert_float(university.reputation).is_equal_approx(UniversityRules.MaxScore, Epsilon)
	university.setReputation(-10.0)
	assert_float(university.reputation).is_equal_approx(0.0, Epsilon)


func test_without_an_admissions_office_the_fall_charges_the_defaults() -> void:
	var university: University = _running()
	university.policy.setNextTuition(Policy.DefaultTuition * 2)
	university.startMonth(GameCalendar.nextFallStart(university.campus.month))
	assert_int(university.policy.current.total()).is_equal(Policy.defaultPrices().total())


func test_every_semester_start_is_reported_and_announced() -> void:
	var university: University = _running()
	var announced: Array[SemesterReport] = []
	university.SemesterStarted.connect(func(report: SemesterReport) -> void: announced.append(report))
	var reportsBefore: int = university.reports.size()
	university.startMonth(GameCalendar.nextFallStart(university.campus.month))
	assert_int(university.reports.size()).is_equal(reportsBefore + 1)
	assert_array(announced).contains_exactly([_last(university)])


func test_a_plain_month_charges_exactly_the_monthly_expenses() -> void:
	var university: University = _running()
	university.finances.borrow(Debt)
	var before: int = university.finances.cash
	var bill: int = university.monthlyExpenses()
	university.startMonth(university.campus.month + 1)
	assert_int(university.finances.cash).is_equal(before - bill)


func _kinds(university: University) -> Array[int]:
	var kinds: Array[int] = []
	for problem: Problem in university.problems():
		kinds.append(problem.kind)
	return kinds


func test_a_healthy_campus_has_no_problems() -> void:
	assert_array(_kinds(_running())).is_empty()


func test_housing_overflow_is_a_problem_only_past_the_threshold() -> void:
	var university: University = _running()
	var allowed: int = floori(float(HallBeds) / (1.0 - UniversityRules.OverflowThreshold)) - Students
	university.students.admit(allowed, Grade)
	assert_array(_kinds(university)).not_contains([Problem.Kind.HousingOverflow])
	university.students.admit(HallBeds, Grade)
	assert_array(_kinds(university)).contains([Problem.Kind.HousingOverflow])


func test_dining_is_crowded_and_then_unfed() -> void:
	var university: University = University.new()
	var building: Building = university.campus.place(BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter, "beds": HallBeds * 10, "meals": HallMeals}), Vector2.ZERO, 0.0)
	university.campus.startMonth(building.opensAtMonth)
	university.students.admit(HallMeals + 1, Grade)
	assert_array(_kinds(university)).contains_exactly([Problem.Kind.DiningCrowded])
	university.students.admit(HallMeals * 2, Grade)
	assert_array(_kinds(university)).contains_exactly([Problem.Kind.DiningUnfed])


func test_a_full_credit_line_is_a_problem() -> void:
	var university: University = _running()
	university.finances.borrow(Finances.CreditLimit)
	assert_array(_kinds(university)).contains([Problem.Kind.CreditMaxed])
