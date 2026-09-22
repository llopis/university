class_name Intake
## One fall admission: how many were admitted and the grade of the weakest.

var admitted: int
var entryGrade: float


func _init(students: int, grade: float) -> void:
	admitted = students
	entryGrade = grade
