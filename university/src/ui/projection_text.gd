class_name ProjectionText
## How next fall's projections are worded, for the Students dropdown and the
## Admissions Office pane alike.

const OpenPlusGraduating: String = "%s open + %s graduating"
const GraduatingFormat: String = "%s graduating"
const IntakeNote: String = "entry grade ≈ %.2f"


## What the seats to fill are made of. Past graduation, what is left beyond the
## graduating class is seats open by next fall; with none, only the graduates.
static func seatsNote(university: University) -> String:
	var toFill: int = university.seatsToFillNextFall()
	var graduating: int = university.graduatingByNextFall()
	if (toFill > graduating):
		return OpenPlusGraduating % [NumberFormat.count(toFill - graduating), NumberFormat.count(graduating)]
	return GraduatingFormat % NumberFormat.count(graduating)


static func intakeNote(intake: Intake) -> String:
	return (IntakeNote % intake.entryGrade) if (intake.admitted > 0) else ""
