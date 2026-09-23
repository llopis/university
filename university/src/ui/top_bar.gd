class_name TopBar
extends PanelContainer
## The bar across the top: the game menu, the crest (the university menu), six
## slots that open their dropdowns, and the clock with the transport controls.
## It owns no state: every number is re-read each frame, because the sim, the
## keys and the console all change them.

signal GameMenuPressed
signal UniversityMenuPressed
signal StudentsPressed
signal HousingPressed
signal MoneyPressed
signal ReputationPressed

const SpeedFormat: String = "%d×"
const SeatsFormat: String = "/ %s seats"
const OffCampusFormat: String = "+%s off campus"
const OwedFormat: String = "%s owed"
const PerMonth: String = "/ month"
const InWeeksFormat: String = "in %d wk"
const FeesCaptionFormat: String = "%s fees"
const TargetUp: String = "↑ %.0f"
const TargetDown: String = "↓ %.0f"
const TargetHeld: String = "→ %.0f"
const ReputationFormat: String = "%.0f"

@onready var menuButton: Button = %MenuButton
@onready var crestButton: Button = %CrestButton
@onready var shieldLetter: Label = %Letter
@onready var universityName: Label = %UniversityName
@onready var studentsSlot: SlotView = %StudentsSlot
@onready var bedsSlot: SlotView = %BedsSlot
@onready var cashSlot: SlotView = %CashSlot
@onready var expensesSlot: SlotView = %ExpensesSlot
@onready var feesSlot: SlotView = %FeesSlot
@onready var reputationSlot: SlotView = %ReputationSlot
@onready var periodLabel: Label = %PeriodLabel
@onready var weekLabel: Label = %WeekLabel
@onready var progress: MeterBar = %Progress
@onready var pauseButton: Button = %PauseButton
@onready var playButton: Button = %PlayButton
@onready var fastButton: Button = %FastButton
@onready var fasterButton: Button = %FasterButton

var state: GameState

# Transport buttons in speed order: index i runs GameState.SpeedSteps[i].
var _speedButtons: Array[Button]
var _toggles: Dictionary[StringName, Button]
# Which of the three money slots was clicked last, so only it reads pressed
# while Money is open.
var _moneySlot: Button


func _ready() -> void:
	_speedButtons = [playButton, fastButton, fasterButton]
	for i: int in range(_speedButtons.size()):
		_speedButtons[i].text = SpeedFormat % GameState.SpeedSteps[i]
		_speedButtons[i].pressed.connect(func() -> void: state.runAt(i))
	pauseButton.pressed.connect(func() -> void: state.setPaused(true))
	menuButton.pressed.connect(func() -> void: GameMenuPressed.emit())
	crestButton.pressed.connect(func() -> void: UniversityMenuPressed.emit())
	studentsSlot.pressed.connect(func() -> void: StudentsPressed.emit())
	bedsSlot.pressed.connect(func() -> void: HousingPressed.emit())
	_moneySlot = cashSlot
	cashSlot.pressed.connect(_onMoneySlotPressed.bind(cashSlot))
	expensesSlot.pressed.connect(_onMoneySlotPressed.bind(expensesSlot))
	feesSlot.pressed.connect(_onMoneySlotPressed.bind(feesSlot))
	reputationSlot.pressed.connect(func() -> void: ReputationPressed.emit())
	_toggles = {
		&"gamemenu": menuButton, &"unimenu": crestButton, &"students": studentsSlot,
		&"housing": bedsSlot, &"reputation": reputationSlot,
	}


func _onMoneySlotPressed(slot: Button) -> void:
	_moneySlot = slot
	MoneyPressed.emit()


## Shows a popover's trigger as pressed while the popover is open. Money
## presses whichever of its three slots was clicked last, defaulting to Cash.
func setOpen(which: StringName, open: bool) -> void:
	if (which == &"money"):
		if (not open):
			_moneySlot = cashSlot
		cashSlot.set_pressed_no_signal(open and _moneySlot == cashSlot)
		expensesSlot.set_pressed_no_signal(open and _moneySlot == expensesSlot)
		feesSlot.set_pressed_no_signal(open and _moneySlot == feesSlot)
		return
	if (_toggles.has(which)):
		_toggles[which].set_pressed_no_signal(open)


func _process(_dt: float) -> void:
	if (state == null):
		return
	var university: University = state.university
	_showCrest(university)
	_showStudents(university)
	_showBeds(university)
	_showMoney(university)
	_showReputation(university)
	_showClock()


func _showCrest(university: University) -> void:
	universityName.text = university.name
	shieldLetter.text = university.name.left(1)


func _showStudents(university: University) -> void:
	studentsSlot.display(NumberFormat.count(university.students.enrolled()),
		SeatsFormat % NumberFormat.count(university.campus.seats()), "Students",
		UiTone.Tone.Normal, UiTone.Tone.Normal, false)


func _showBeds(university: University) -> void:
	var overflowing: bool = university.hasProblem(Problem.Kind.HousingOverflow)
	var offCampus: int = university.offCampus()
	bedsSlot.display(NumberFormat.count(university.housed()),
		(OffCampusFormat % NumberFormat.count(offCampus)) if (offCampus > 0) else "", "Beds",
		UiTone.Tone.Normal, UiTone.Tone.Warn if (overflowing) else UiTone.Tone.Normal, overflowing)


func _showMoney(university: University) -> void:
	var finances: Finances = university.finances
	cashSlot.display(MoneyFormat.short(finances.cash),
		(OwedFormat % MoneyFormat.short(finances.debt)) if (finances.debt > 0) else "", "Cash",
		UiTone.Tone.Normal, UiTone.Tone.Normal, false)
	expensesSlot.display(MoneyFormat.signed(-university.monthlyExpenses()), PerMonth, "Monthly expenses",
		UiTone.Tone.Bad, UiTone.Tone.Normal, false)
	var start: int = university.nextSemesterStart()
	feesSlot.display(MoneyFormat.signed(university.projectedFees().total()),
		InWeeksFormat % GameCalendar.weeksUntil(state.week(), start),
		FeesCaptionFormat % GameCalendar.PeriodNames[GameCalendar.period(start)],
		UiTone.Tone.Good, UiTone.Tone.Normal, false)


func _showReputation(university: University) -> void:
	var target: float = university.reputationTarget()
	var tone: UiTone.Tone = UiTone.trend(university.reputation, target)
	var trend: String = TargetHeld
	if (tone == UiTone.Tone.Good):
		trend = TargetUp
	elif (tone == UiTone.Tone.Bad):
		trend = TargetDown
	reputationSlot.display(ReputationFormat % university.reputation, trend % target, "Reputation",
		UiTone.Tone.Normal, tone, false)


func _showClock() -> void:
	var week: int = state.week()
	periodLabel.text = GameCalendar.periodLabel(state.month())
	weekLabel.text = GameCalendar.clockLine(week)
	var inPeriod: float = float(GameCalendar.weekInPeriod(week)) / float(GameCalendar.weeksInPeriod(state.month()))
	var noMarks: Array[float] = []
	progress.setValue(inPeriod, UiTone.Tone.Normal, noMarks, MeterBar.NoLimit)
	# Exactly one transport button reads as pressed.
	pauseButton.set_pressed_no_signal(state.paused)
	for i: int in range(_speedButtons.size()):
		_speedButtons[i].set_pressed_no_signal(not state.paused and state.speedIndex == i)
