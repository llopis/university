class_name Cohort
## One fall's intake, from admission to graduation: how many students it has,
## the grade of the weakest one admitted, and how many semesters it has
## completed. A cohort never shrinks; it graduates whole.

# Keys toDict writes; fromDict refuses a dictionary missing any of them.
const SavedKeys: Array[String] = ["size", "entryGrade", "semestersCompleted"]

var size: int
var entryGrade: float
var semestersCompleted: int = 0


func _init(students: int, grade: float) -> void:
	size = students
	entryGrade = grade


## The academic year whose spring this cohort finishes, seen from monthIndex:
## "Class of Year N". It graduates at the semester start that completes its
## course, which falls in the next academic year.
func graduationYear(monthIndex: int) -> int:
	var graduation: int = monthIndex
	for _semester: int in range(StudentBody.SemestersToGraduate - semestersCompleted):
		graduation = GameCalendar.nextSemesterStart(graduation)
	return GameCalendar.year(graduation) - 1


func toDict() -> Dictionary:
	return {"size": size, "entryGrade": entryGrade, "semestersCompleted": semestersCompleted}


## Null when data is missing a key.
static func fromDict(data: Dictionary) -> Cohort:
	if (not Variants.hasKeys(data, SavedKeys, "Cohort")):
		return null
	var cohort: Cohort = Cohort.new(maxi(Variants.toInt(data["size"]), 0), Variants.toFloat(data["entryGrade"]))
	cohort.semestersCompleted = maxi(Variants.toInt(data["semestersCompleted"]), 0)
	return cohort
