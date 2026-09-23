extends GdUnitTestSuite
## Students as cohorts: enrolment, graduation after the full course, and the
## save round trip. Sizes and grades are arbitrary fixtures.

const Size: int = 120
const Grade: float = 3.1
const OtherSize: int = 90


func test_enrolment_is_every_cohort_together() -> void:
	var body: StudentBody = StudentBody.new()
	body.admit(Size, Grade)
	body.admit(OtherSize, Grade)
	assert_int(body.enrolled()).is_equal(Size + OtherSize)


func test_admitting_no_one_adds_no_cohort() -> void:
	var body: StudentBody = StudentBody.new()
	body.admit(0, Grade)
	assert_array(body.cohorts).is_empty()


func test_a_cohort_graduates_after_the_full_course_and_not_before() -> void:
	var body: StudentBody = StudentBody.new()
	body.admit(Size, Grade)
	for _semester: int in range(StudentBody.SemestersToGraduate - 1):
		assert_int(body.completeSemester()).is_equal(0)
	assert_int(body.enrolled()).is_equal(Size)
	assert_int(body.completeSemester()).is_equal(Size)
	assert_int(body.enrolled()).is_equal(0)


func test_a_round_trip_keeps_every_cohort() -> void:
	var body: StudentBody = StudentBody.new()
	body.admit(Size, Grade)
	body.completeSemester()
	body.admit(OtherSize, Grade)
	var back: StudentBody = StudentBody.fromDict(SaveFile.decode(SaveFile.encode(body.toDict())) as Dictionary)
	assert_str(SaveFile.encode(back.toDict())).is_equal(SaveFile.encode(body.toDict()))


func test_a_cohort_missing_a_key_is_refused() -> void:
	var body: StudentBody = StudentBody.new()
	body.admit(Size, Grade)
	var data: Dictionary = body.toDict()
	((data["cohorts"] as Array)[0] as Dictionary).erase("entryGrade")
	var loaded: Array[StudentBody] = []
	await assert_error(func() -> void: loaded.append(StudentBody.fromDict(data))) \
		.is_push_error(Variants.MissingKeysError % ["Cohort", "entryGrade"])
	assert_object(loaded[0]).is_null()


func test_graduating_within_counts_the_cohorts_that_finish_in_time() -> void:
	var body: StudentBody = StudentBody.new()
	body.admit(Size, Grade)
	body.admit(OtherSize, Grade)
	body.cohorts[0].semestersCompleted = StudentBody.SemestersToGraduate - 2
	assert_int(body.graduatingWithin(1)).is_equal(0)
	assert_int(body.graduatingWithin(2)).is_equal(Size)


func test_a_class_is_named_for_the_year_whose_spring_it_finishes() -> void:
	var fresh: Cohort = Cohort.new(Size, Grade)
	var finishing: Cohort = Cohort.new(Size, Grade)
	finishing.semestersCompleted = StudentBody.SemestersToGraduate - 2
	# At the first fall start (month 0), a new class finishes three springs on,
	# and one with two semesters left finishes this academic year's spring.
	assert_int(fresh.graduationYear(0)).is_equal(GameCalendar.FirstYear + 3)
	assert_int(finishing.graduationYear(0)).is_equal(GameCalendar.FirstYear)
