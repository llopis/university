extends GdUnitTestSuite
## How next fall's seat and intake projections are worded. Fixtures are arbitrary.

const Diameter: float = 20.0
const FreshSize: int = 150
const GraduatingSize: int = 50
const Grade: float = 3.0
const AdmittedCount: int = 40
const SeatsBeyondGraduation: int = 300
const SeatsAtGraduation: int = 200


func _hall(seats: int) -> BuildingInfo:
	return BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter, "seats": seats})


## A university with a fresh cohort, a second cohort due to graduate exactly
## by the next fall start, and one open-by-then academic building of the given
## size.
func _university(seats: int) -> University:
	var university: University = University.new()
	university.campus.place(_hall(seats), Vector2.ZERO, 0.0)
	university.students.admit(FreshSize, Grade)
	var semestersLeft: int = GameCalendar.semesterStartsBetween(university.campus.month, university.nextFallStart())
	var graduating: Cohort = Cohort.new(GraduatingSize, Grade)
	graduating.semestersCompleted = StudentBody.SemestersToGraduate - semestersLeft
	university.students.cohorts.append(graduating)
	return university


func test_seats_note() -> void:
	# Seats open beyond the graduating class: both counts appear.
	var beyond: University = _university(SeatsBeyondGraduation)
	var toFill: int = beyond.seatsToFillNextFall()
	var graduating: int = beyond.graduatingByNextFall()
	assert_int(toFill).is_greater(graduating)
	var beyondNote: String = ProjectionText.seatsNote(beyond)
	assert_str(beyondNote).contains(NumberFormat.count(toFill - graduating))
	assert_str(beyondNote).contains(NumberFormat.count(graduating))

	# None beyond them: only the graduating count, in the plain form.
	var atGraduation: University = _university(SeatsAtGraduation)
	var evenToFill: int = atGraduation.seatsToFillNextFall()
	var evenGraduating: int = atGraduation.graduatingByNextFall()
	assert_int(evenToFill).is_less_equal(evenGraduating)
	var evenNote: String = ProjectionText.seatsNote(atGraduation)
	assert_str(evenNote).is_equal(ProjectionText.GraduatingFormat % NumberFormat.count(evenGraduating))


func test_intake_note() -> void:
	var none: Intake = Intake.new(0, 0.0)
	assert_str(ProjectionText.intakeNote(none)).is_empty()

	var admitted: Intake = Intake.new(AdmittedCount, Grade)
	assert_str(ProjectionText.intakeNote(admitted)).contains("%.2f" % Grade)
