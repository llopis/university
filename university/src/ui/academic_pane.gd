class_name AcademicPane
extends VBoxContainer
## What the open academic buildings hold and who fills them: enrolled against
## every open seat, this fall's entry grade, and each open academic building
## with what it holds and costs. Follows the pane pattern: filled every
## `_process` while visible, its building list rebuilt on `visibility_changed`
## and when the shown building changes.

signal PopoverWanted(which: StringName)
signal BuildWanted(category: String)
signal BuildingWanted(building: Building)

const StudentsFormat: String = "%s / %s"
const StudentsCaption: String = "Students / seats"
const OpenSeatsCaption: String = "Open seats"
const GradeFormat: String = "%.2f"
const GradeCaption: String = "Entry grade"
const SeatsNoteFormat: String = "%s students graduate before next fall, so next fall can take about %s with the buildings you have. Full classes are fine."
const ListTitleFormat: String = "Academic buildings · %d"
const RowFormat: String = "%s   %s · %s / mo"

@onready var studentsKpi: KpiView = %StudentsKpi
@onready var openSeatsKpi: KpiView = %OpenSeatsKpi
@onready var gradeKpi: KpiView = %GradeKpi
@onready var seatsBar: MeterBar = %SeatsBar
@onready var seatsNote: Label = %SeatsNote
@onready var listTitle: Label = %ListTitle
@onready var list: VBoxContainer = %List
@onready var addButton: Button = %AddButton
@onready var studentsJump: Button = %StudentsJump
@onready var admissionsJump: Button = %AdmissionsJump

var university: University
var building: Building

var _lastBuilding: Building


func _ready() -> void:
	addButton.pressed.connect(func() -> void: BuildWanted.emit(building.info.category))
	studentsJump.pressed.connect(func() -> void: PopoverWanted.emit(&"students"))
	admissionsJump.pressed.connect(_onAdmissionsJumpPressed)
	visibility_changed.connect(_rebuildList)


func setUniversity(shown: University) -> void:
	university = shown


func _process(_dt: float) -> void:
	if (university == null or building == null or not visible):
		return
	if (building != _lastBuilding):
		_lastBuilding = building
		_rebuildList()
	var campus: Campus = university.campus
	var enrolled: int = university.students.enrolled()
	var seats: int = campus.seats()
	studentsKpi.display(StudentsFormat % [NumberFormat.count(enrolled), NumberFormat.count(seats)], StudentsCaption)
	openSeatsKpi.display(NumberFormat.count(university.openSeats()), OpenSeatsCaption)
	gradeKpi.display(GradeFormat % university.lastIntakeGrade, GradeCaption)
	var fraction: float = (float(enrolled) / float(seats)) if (seats > 0) else 0.0
	var noMarks: Array[float] = []
	seatsBar.setValue(fraction, UiTone.Tone.Good, noMarks, MeterBar.NoLimit)
	seatsNote.text = SeatsNoteFormat % [NumberFormat.count(university.graduatingByNextFall()), NumberFormat.count(university.seatsToFillNextFall())]
	var academicBuildings: Array[Building] = campus.openWithRole(BuildingInfo.Role.Academic)
	listTitle.text = ListTitleFormat % academicBuildings.size()
	admissionsJump.visible = not campus.openWithRole(BuildingInfo.Role.Admissions).is_empty()


func _rebuildList() -> void:
	if (university == null or not visible):
		return
	while (list.get_child_count() > 0):
		var old: Node = list.get_child(list.get_child_count() - 1)
		list.remove_child(old)
		old.queue_free()
	for entry: Building in university.campus.openWithRole(BuildingInfo.Role.Academic):
		var row: Button = Button.new()
		row.theme_type_variation = &"BuildingRow"
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = RowFormat % [entry.info.name, BuildingText.holds(entry.info), MoneyFormat.short(entry.info.upkeep)]
		row.pressed.connect(func() -> void: BuildingWanted.emit(entry))
		list.add_child(row)


func _onAdmissionsJumpPressed() -> void:
	var admissions: Array[Building] = university.campus.openWithRole(BuildingInfo.Role.Admissions)
	if (not admissions.is_empty()):
		BuildingWanted.emit(admissions[0])
