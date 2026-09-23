class_name StudentBody
## Every student enrolled, as cohorts: one per fall intake. At each semester
## start every cohort completes a semester, and those that have completed
## SemestersToGraduate leave together.

const SemestersToGraduate: int = 8
# Keys toDict writes; fromDict refuses a dictionary missing any of them.
const SavedKeys: Array[String] = ["cohorts"]

var cohorts: Array[Cohort]


func enrolled() -> int:
	var total: int = 0
	for cohort: Cohort in cohorts:
		total += cohort.size
	return total


## A semester began: every cohort has completed one more, and those that have
## completed the full course graduate. Returns how many students graduated.
func completeSemester() -> int:
	var graduated: int = 0
	var staying: Array[Cohort] = []
	for cohort: Cohort in cohorts:
		cohort.semestersCompleted += 1
		if (cohort.semestersCompleted >= SemestersToGraduate):
			graduated += cohort.size
		else:
			staying.append(cohort)
	cohorts = staying
	return graduated


## Students whose cohorts will have completed the course within that many more
## semester starts: those graduating by then.
func graduatingWithin(semesterStarts: int) -> int:
	var total: int = 0
	for cohort: Cohort in cohorts:
		if (cohort.semestersCompleted + semesterStarts >= SemestersToGraduate):
			total += cohort.size
	return total


## A fall intake joins. Admitting no one adds no cohort.
func admit(size: int, grade: float) -> void:
	if (size > 0):
		cohorts.append(Cohort.new(size, grade))


func toDict() -> Dictionary:
	var saved: Array[Dictionary] = []
	for cohort: Cohort in cohorts:
		saved.append(cohort.toDict())
	return {"cohorts": saved}


## Null when data, or any cohort in it, is missing a key.
static func fromDict(data: Dictionary) -> StudentBody:
	if (not Variants.hasKeys(data, SavedKeys, "StudentBody")):
		return null
	var body: StudentBody = StudentBody.new()
	for saved: Variant in data["cohorts"] as Array:
		var cohort: Cohort = Cohort.fromDict(saved as Dictionary)
		if (cohort == null):
			return null
		body.cohorts.append(cohort)
	return body
