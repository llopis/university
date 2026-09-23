class_name AdmissionsPane
extends VBoxContainer
## What the Admissions Office lets the player see and set: next fall's live
## projection as three stages, applicants per fall as a bar chart, and the
## levers (minimum entry grade, tuition, room and meal plan) that apply from
## next fall. Follows the pane pattern: filled every `_process` while visible,
## its jumps only announce `PopoverWanted` for `SidePanel` to relay.

signal PopoverWanted(which: StringName)

const IntakeTitleFormat: String = "Next intake · %s"
const ApplyNoteFormat: String = "apply from %s"
const ApproxFormat: String = "≈ %s"
const ApplicantsDetailFormat: String = "reputation %.0f · %s a semester"
const MinimumCaption: String = "Minimum"
const MinimumOff: String = "Off"
const MinimumValueFormat: String = "%.1f"
const NextYearCaption: String = "Next year"
const TuitionNowFormat: String = "This year %s"
const RoomCaption: String = "Room"
const MealCaption: String = "Meal plan"
const HousingNowFormat: String = "This year %s · %s"
const TotalNoteFormat: String = "Applicants weigh the total: %s a semester. Off-campus students pay tuition only."
const YearFormat: String = "Y%d"
# How many of the latest falls the chart shows, and the tallest bar's height.
const ChartFalls: int = 5
const ChartHeight: float = 56.0

@onready var intakeTitle: Label = %IntakeTitle
@onready var seatsValue: Label = %SeatsValue
@onready var seatsDetail: Label = %SeatsDetail
@onready var applicantsValue: Label = %ApplicantsValue
@onready var applicantsDetail: Label = %ApplicantsDetail
@onready var intakeValue: Label = %IntakeValue
@onready var intakeDetail: Label = %IntakeDetail
@onready var chart: HBoxContainer = %Chart
@onready var noFallsNote: Label = %NoFallsNote
@onready var applyNote: Label = %ApplyNote
@onready var minimumStepper: Stepper = %MinimumStepper
@onready var tuitionNow: Label = %TuitionNow
@onready var tuitionStepper: Stepper = %TuitionStepper
@onready var housingNow: Label = %HousingNow
@onready var roomStepper: Stepper = %RoomStepper
@onready var mealStepper: Stepper = %MealStepper
@onready var totalNote: Label = %TotalNote
@onready var studentsJump: Button = %StudentsJump
@onready var financesJump: Button = %FinancesJump

var university: University
var building: Building


func _ready() -> void:
	minimumStepper.Stepped.connect(func(direction: int) -> void:
		if (university != null):
			university.policy.stepMinimum(direction))
	tuitionStepper.Stepped.connect(func(direction: int) -> void:
		if (university != null):
			university.policy.stepNextTuition(direction))
	roomStepper.Stepped.connect(func(direction: int) -> void:
		if (university != null):
			university.policy.stepNextRoom(direction))
	mealStepper.Stepped.connect(func(direction: int) -> void:
		if (university != null):
			university.policy.stepNextMealPlan(direction))
	studentsJump.pressed.connect(func() -> void: PopoverWanted.emit(Hud.PopoverStudents))
	financesJump.pressed.connect(func() -> void: PopoverWanted.emit(Hud.PopoverMoney))
	visibility_changed.connect(_rebuildChart)


func setUniversity(shown: University) -> void:
	university = shown
	shown.SemesterStarted.connect(func(_report: SemesterReport) -> void: _rebuildChart())


func _process(_dt: float) -> void:
	if (university == null or not visible):
		return
	intakeTitle.text = IntakeTitleFormat % GameCalendar.periodLabel(university.nextFallStart())
	_showStages()
	applyNote.text = ApplyNoteFormat % GameCalendar.periodLabel(university.nextFallStart())
	_showLevers()


func _showStages() -> void:
	seatsValue.text = ApproxFormat % NumberFormat.count(university.seatsToFillNextFall())
	seatsDetail.text = ProjectionText.seatsNote(university)
	applicantsValue.text = ApproxFormat % NumberFormat.count(university.expectedApplicants())
	applicantsDetail.text = ApplicantsDetailFormat % [university.reputation, MoneyFormat.full(university.pricesAt(university.nextFallStart()).total())]
	var intake: Intake = university.expectedIntake()
	intakeValue.text = ApproxFormat % NumberFormat.count(intake.admitted)
	intakeDetail.text = ProjectionText.intakeNote(intake)


func _showLevers() -> void:
	var policy: Policy = university.policy
	var minimum: float = policy.minimumGrade
	minimumStepper.display(MinimumCaption, MinimumOff if (minimum <= 0.0) else (MinimumValueFormat % minimum), minimum <= 0.0)
	tuitionNow.text = TuitionNowFormat % MoneyFormat.full(policy.current.tuition)
	tuitionStepper.display(NextYearCaption, MoneyFormat.full(policy.next.tuition), false)
	housingNow.text = HousingNowFormat % [MoneyFormat.full(policy.current.room), MoneyFormat.full(policy.current.mealPlan)]
	roomStepper.display(RoomCaption, MoneyFormat.full(policy.next.room), false)
	mealStepper.display(MealCaption, MoneyFormat.full(policy.next.mealPlan), false)
	totalNote.text = TotalNoteFormat % MoneyFormat.full(university.pricesAt(university.nextFallStart()).total())


func _rebuildChart() -> void:
	if (university == null or not visible):
		return
	while (chart.get_child_count() > 0):
		var child: Node = chart.get_child(chart.get_child_count() - 1)
		chart.remove_child(child)
		child.queue_free()
	var falls: Array[SemesterReport] = university.fallReports()
	noFallsNote.visible = falls.is_empty()
	chart.visible = not noFallsNote.visible
	if (noFallsNote.visible):
		return
	var start: int = maxi(falls.size() - ChartFalls, 0)
	var most: int = 0
	for i: int in range(start, falls.size()):
		most = maxi(most, falls[i].applicants)
	# Fixed slots: empty columns lead so the shown reports sit in the rightmost
	# columns, oldest to latest, and the latest (gold) bar is always on the right.
	for i: int in range(ChartFalls - (falls.size() - start)):
		chart.add_child(_makeEmptySlot())
	for i: int in range(start, falls.size()):
		chart.add_child(_makeBar(falls[i], i == falls.size() - 1, most))


func _makeEmptySlot() -> VBoxContainer:
	var slot: VBoxContainer = VBoxContainer.new()
	slot.size_flags_horizontal = SIZE_EXPAND_FILL
	return slot


func _makeBar(report: SemesterReport, latest: bool, most: int) -> VBoxContainer:
	var bar: VBoxContainer = VBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.size_flags_horizontal = SIZE_EXPAND_FILL

	var countLabel: Label = Label.new()
	countLabel.text = NumberFormat.count(report.applicants)
	countLabel.theme_type_variation = &"Caption"
	countLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(countLabel)

	var fill: Panel = Panel.new()
	fill.theme_type_variation = &"MiniBarOn" if (latest) else &"MiniBar"
	fill.custom_minimum_size.y = ChartHeight * float(report.applicants) / float(maxi(most, 1))
	bar.add_child(fill)

	var yearLabel: Label = Label.new()
	yearLabel.text = YearFormat % GameCalendar.year(report.month)
	yearLabel.theme_type_variation = &"Caption"
	yearLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(yearLabel)

	return bar
