class_name StudentsDropdown
extends PanelContainer
## Who is enrolled: the headline numbers, the classes, where they live, and
## what next fall looks like at today's reputation and next year's prices.

signal HousingJumped
signal ReputationJumped

const TitleFormat: String = "Students · %s"
const NextFallFormat: String = "Next fall · Year %d"
const ClassFormat: String = "Class of Year %d"
const GradeFormat: String = "%.2f"
const OutOfFormat: String = "%s / %s beds"
const ShareFormat: String = "%s · %s"
const PlusFormat: String = "+%s beds"
const ApproxFormat: String = "≈ %s"
const OpenPlusGraduating: String = "%s open + %s graduating"
const IntakeNote: String = "entry grade ≈ %.2f"
const Nothing: String = "—"
const OverThresholdPill: String = "above %s threshold"
const EnrolledCaption: String = "Enrolled"
const OpenSeatsCaption: String = "Open seats"
const AdmittedCaption: String = "Admitted this fall"
const GraduatingCaption: String = "Graduating before fall"
const GradeCaption: String = "This fall's entry grade"
const OnCampusKey: String = "On campus"
const OffCampusKey: String = "Off campus"
const OpeningKeyFormat: String = "Opening %s"
const SeatsToFillKey: String = "Seats to fill"
const ApplicantsKey: String = "Expected applicants"
const IntakeKey: String = "Expected intake"

@onready var title: Label = %Title
@onready var enrolledKpi: KpiView = %EnrolledKpi
@onready var openSeatsKpi: KpiView = %OpenSeatsKpi
@onready var admittedKpi: KpiView = %AdmittedKpi
@onready var graduatingKpi: KpiView = %GraduatingKpi
@onready var gradeKpi: KpiView = %GradeKpi
@onready var cohortsGrid: GridContainer = %Cohorts
@onready var onCampusRow: InfoRow = %OnCampusRow
@onready var offCampusRow: InfoRow = %OffCampusRow
@onready var openingRow: InfoRow = %OpeningRow
@onready var nextFallTitle: Label = %NextFallTitle
@onready var seatsToFillRow: InfoRow = %SeatsToFillRow
@onready var applicantsRow: InfoRow = %ApplicantsRow
@onready var intakeRow: InfoRow = %IntakeRow
@onready var housingJump: Button = %HousingJump
@onready var reputationJump: Button = %ReputationJump

var university: University
# The header labels the table starts with; rows follow them.
var _headerCount: int = 0


func _ready() -> void:
	_headerCount = cohortsGrid.get_child_count()
	visibility_changed.connect(_rebuildCohorts)
	housingJump.pressed.connect(func() -> void: HousingJumped.emit())
	reputationJump.pressed.connect(func() -> void: ReputationJumped.emit())


func setUniversity(shown: University) -> void:
	university = shown
	university.SemesterStarted.connect(func(_report: SemesterReport) -> void: _rebuildCohorts())


func _process(_dt: float) -> void:
	if (university == null or not visible):
		return
	var month: int = university.campus.month
	title.text = TitleFormat % GameCalendar.periodLabel(month)
	var enrolledCount: int = university.students.enrolled()
	var seatsNow: int = university.campus.seats()
	enrolledKpi.display(NumberFormat.count(enrolledCount), EnrolledCaption)
	openSeatsKpi.display(NumberFormat.count(maxi(seatsNow - enrolledCount, 0)), OpenSeatsCaption)
	var fall: SemesterReport = university.lastFallReport()
	admittedKpi.display(NumberFormat.count(fall.admitted) if (fall != null) else Nothing, AdmittedCaption)
	graduatingKpi.display(NumberFormat.count(university.graduatingByNextFall()), GraduatingCaption)
	gradeKpi.display((GradeFormat % fall.entryGrade) if (fall != null and fall.admitted > 0) else Nothing, GradeCaption)
	_showHousing()
	_showNextFall()


func _showHousing() -> void:
	var offCampus: int = university.offCampus()
	var share: float = university.offCampusShare()
	var over: bool = university.hasProblem(Problem.Kind.HousingOverflow)
	onCampusRow.display(OnCampusKey, OutOfFormat % [NumberFormat.count(university.housed()), NumberFormat.count(university.campus.beds())])
	offCampusRow.display(OffCampusKey, ShareFormat % [NumberFormat.count(offCampus), NumberFormat.percent(share)], "",
		UiTone.Tone.Warn if (over) else UiTone.Tone.Normal)
	offCampusRow.showPill((OverThresholdPill % NumberFormat.percent(UniversityRules.OverflowThreshold)) if (over) else "", UiTone.Tone.Warn)
	var start: int = university.nextSemesterStart()
	var opening: int = university.campus.bedsBy(start) - university.campus.beds()
	openingRow.visible = (opening > 0)
	openingRow.display(OpeningKeyFormat % GameCalendar.periodLabel(start), PlusFormat % NumberFormat.count(opening))


func _showNextFall() -> void:
	var fall: int = university.nextFallStart()
	nextFallTitle.text = NextFallFormat % GameCalendar.year(fall)
	var toFill: int = university.seatsToFillNextFall()
	var graduating: int = university.graduatingByNextFall()
	seatsToFillRow.display(SeatsToFillKey, ApproxFormat % NumberFormat.count(toFill),
		OpenPlusGraduating % [NumberFormat.count(toFill - graduating), NumberFormat.count(graduating)])
	applicantsRow.display(ApplicantsKey, ApproxFormat % NumberFormat.count(university.expectedApplicants()))
	var intake: Intake = university.expectedIntake()
	intakeRow.display(IntakeKey, ApproxFormat % NumberFormat.count(intake.admitted),
		(IntakeNote % intake.entryGrade) if (intake.admitted > 0) else "")


func _rebuildCohorts() -> void:
	if (university == null or not visible):
		return
	while (cohortsGrid.get_child_count() > _headerCount):
		var row: Node = cohortsGrid.get_child(cohortsGrid.get_child_count() - 1)
		cohortsGrid.remove_child(row)
		row.queue_free()
	var month: int = university.campus.month
	# Oldest first: the class that graduates soonest leads.
	var ordered: Array[Cohort] = []
	ordered.assign(university.students.cohorts)
	ordered.sort_custom(func(a: Cohort, b: Cohort) -> bool: return a.semestersCompleted > b.semestersCompleted)
	for cohort: Cohort in ordered:
		_addCell(ClassFormat % cohort.graduationYear(month), &"RowValue")
		_addCell(NumberFormat.count(cohort.size), &"RowKey")
		_addCell(GradeFormat % cohort.entryGrade, &"RowKey")
		_addCell(str(StudentBody.SemestersToGraduate - cohort.semestersCompleted), &"RowKey")


func _addCell(text: String, variation: StringName) -> void:
	var cell: Label = Label.new()
	cell.text = text
	cell.theme_type_variation = variation
	cohortsGrid.add_child(cell)
