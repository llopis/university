extends GdUnitTestSuite
## Month indexes into dates and semesters. Month index 0 is where the game
## starts; the assertions are about how the calendar moves from there.


func test_the_game_starts_in_september_of_the_first_year() -> void:
	assert_str(GameCalendar.label(0)).is_equal("Sep, Year 1")


func test_months_follow_the_calendar_and_wrap_after_december() -> void:
	assert_str(GameCalendar.monthName(3)).is_equal("Dec")
	assert_str(GameCalendar.monthName(4)).is_equal("Jan")


func test_the_year_is_academic_and_turns_over_in_september() -> void:
	var lastOfYearOne: int = GameCalendar.MonthsPerYear - 1
	assert_int(GameCalendar.year(lastOfYearOne)).is_equal(GameCalendar.FirstYear)
	assert_int(GameCalendar.year(lastOfYearOne + 1)).is_equal(GameCalendar.FirstYear + 1)
	assert_str(GameCalendar.monthName(lastOfYearOne + 1)).is_equal(GameCalendar.monthName(0))


func test_january_does_not_change_the_year() -> void:
	assert_int(GameCalendar.year(4)).is_equal(GameCalendar.year(3))


func test_semesters_start_in_september_and_february() -> void:
	var starts: Array[String] = []
	for monthIndex: int in range(GameCalendar.MonthsPerYear):
		if (GameCalendar.isSemesterStart(monthIndex)):
			starts.append(GameCalendar.monthName(monthIndex))
	assert_array(starts).contains_exactly(["Sep", "Feb"])


func test_next_semester_is_strictly_after_the_given_month() -> void:
	# From a month that itself starts a semester, the next one is the OTHER one.
	var fromSeptember: int = GameCalendar.nextSemesterStart(0)
	assert_str(GameCalendar.monthName(fromSeptember)).is_equal("Feb")
	var fromFebruary: int = GameCalendar.nextSemesterStart(fromSeptember)
	assert_str(GameCalendar.monthName(fromFebruary)).is_equal("Sep")
	assert_int(fromFebruary).is_equal(GameCalendar.MonthsPerYear)


func test_next_semester_from_the_month_before_is_one_month_away() -> void:
	var february: int = GameCalendar.nextSemesterStart(0)
	assert_int(GameCalendar.nextSemesterStart(february - 1)).is_equal(february)


func test_only_september_starts_a_fall() -> void:
	assert_bool(GameCalendar.isFallStart(0)).is_true()
	assert_bool(GameCalendar.isFallStart(GameCalendar.MonthsPerYear)).is_true()
	assert_bool(GameCalendar.isFallStart(GameCalendar.nextSemesterStart(0))).is_false()


func test_next_fall_is_strictly_after_the_given_month() -> void:
	# From a month that itself starts a fall, the next one is a year later.
	assert_int(GameCalendar.nextFallStart(0)).is_equal(GameCalendar.MonthsPerYear)
	var february: int = GameCalendar.nextSemesterStart(0)
	assert_int(GameCalendar.nextFallStart(february)).is_equal(GameCalendar.MonthsPerYear)


func test_semester_starts_between_count_only_those_after_the_first_month() -> void:
	var fall: int = GameCalendar.MonthsPerYear
	assert_int(GameCalendar.semesterStartsBetween(0, fall)).is_equal(2)
	assert_int(GameCalendar.semesterStartsBetween(GameCalendar.nextSemesterStart(0), fall)).is_equal(1)
	assert_int(GameCalendar.semesterStartsBetween(fall, fall)).is_equal(0)


func test_periods_run_fall_spring_summer_and_cover_the_year() -> void:
	var fall: int = 0
	var spring: int = GameCalendar.nextSemesterStart(0)
	assert_int(GameCalendar.period(fall)).is_equal(GameCalendar.Period.Fall)
	assert_int(GameCalendar.period(spring)).is_equal(GameCalendar.Period.Spring)
	var weeks: int = 0
	var monthIndex: int = 0
	while (monthIndex < GameCalendar.MonthsPerYear):
		weeks += GameCalendar.weeksInPeriod(monthIndex)
		var here: GameCalendar.Period = GameCalendar.period(monthIndex)
		while (monthIndex < GameCalendar.MonthsPerYear and GameCalendar.period(monthIndex) == here):
			monthIndex += 1
	assert_int(weeks).is_equal(GameCalendar.MonthsPerYear * GameCalendar.WeeksPerMonth)
	assert_str(GameCalendar.periodLabel(spring)).contains(GameCalendar.PeriodNames[GameCalendar.Period.Spring])


func test_weeks_count_up_through_a_period_and_start_again_at_the_next() -> void:
	var weeks: int = GameCalendar.weeksInPeriod(0)
	assert_int(GameCalendar.weekInPeriod(0)).is_equal(1)
	assert_int(GameCalendar.weekInPeriod(weeks - 1)).is_equal(weeks)
	assert_int(GameCalendar.weekInPeriod(weeks)).is_equal(1)


func test_the_clock_line_names_the_week_and_the_periods_length() -> void:
	var line: String = GameCalendar.clockLine(0)
	assert_str(line).contains("Week 1 of %d" % GameCalendar.weeksInPeriod(0))
