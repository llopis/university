class_name MoneyDropdown
extends Control
## The money in full: cash and what it costs each month, the credit line with
## its Borrow/Repay buttons, and the coming semester's fees at today's
## enrolment.

signal CloseRequested

const CashCaption: String = "Cash"
const PerMonthCaption: String = "Per month"
const AtStartCaption: String = "Cash at semester start"
const UpkeepKey: String = "Building upkeep"
const InterestKey: String = "Interest"
const TotalKey: String = "Total"
const ShortfallNoteFormat: String = "If a month's bill is more than the cash, the shortfall is borrowed automatically, plus a %s fee."
const OwedKey: String = "Owed"
const OwedNoteFormat: String = "%s a year · %s / mo"
const CreditLeftKey: String = "Credit left"
const CreditLeftNoteFormat: String = "of %s"
const BorrowFormat: String = "Borrow %s"
const RepayFormat: String = "Repay %s"
const FeesTitleFormat: String = "%s fees · in %d weeks"
const TuitionKeyFormat: String = "Tuition · %s students"
const RoomKeyFormat: String = "Room · %s beds"
const MealsKeyFormat: String = "Meal plans · %s"
const EachFormat: String = "%s each"
const AfterFeesKey: String = "Cash after fees"
const ApproxFormat: String = "≈ %s"

@onready var dim: Panel = %Dim
@onready var cashKpi: KpiView = %CashKpi
@onready var perMonthKpi: KpiView = %PerMonthKpi
@onready var atStartKpi: KpiView = %AtStartKpi
@onready var upkeepRow: InfoRow = %UpkeepRow
@onready var interestRow: InfoRow = %InterestRow
@onready var monthTotalRow: InfoRow = %MonthTotalRow
@onready var everyMonthHelp: HelpIcon = %EveryMonthHelp
@onready var owedRow: InfoRow = %OwedRow
@onready var creditLeftRow: InfoRow = %CreditLeftRow
@onready var borrowButton: Button = %BorrowButton
@onready var repayButton: Button = %RepayButton
@onready var feesTitle: Label = %FeesTitle
@onready var tuitionRow: InfoRow = %TuitionRow
@onready var roomRow: InfoRow = %RoomRow
@onready var mealsRow: InfoRow = %MealsRow
@onready var feesTotalRow: InfoRow = %FeesTotalRow
@onready var afterFeesRow: InfoRow = %AfterFeesRow

var state: GameState


func _ready() -> void:
	dim.gui_input.connect(_onDimInput)
	everyMonthHelp.tooltip_text = ShortfallNoteFormat % NumberFormat.percent(Finances.ShortfallFee)
	borrowButton.text = BorrowFormat % MoneyFormat.short(Finances.LoanStep)
	repayButton.text = RepayFormat % MoneyFormat.short(Finances.LoanStep)
	borrowButton.pressed.connect(func() -> void: state.university.finances.borrow(Finances.LoanStep))
	repayButton.pressed.connect(func() -> void: state.university.finances.repay(Finances.LoanStep))


func _onDimInput(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		CloseRequested.emit()
		accept_event()


func setState(gameState: GameState) -> void:
	state = gameState


func _process(_dt: float) -> void:
	if (state == null or not visible):
		return
	var university: University = state.university
	var finances: Finances = university.finances
	_showKpis(university, finances)
	_showMonthly(university, finances)
	_showCredit(finances)
	_showFees(university)


func _showKpis(university: University, finances: Finances) -> void:
	cashKpi.display(MoneyFormat.short(finances.cash), CashCaption)
	perMonthKpi.display(MoneyFormat.signed(-university.monthlyExpenses()), PerMonthCaption, UiTone.Tone.Bad)
	var atStart: int = university.cashAtSemesterStart()
	atStartKpi.display(MoneyFormat.short(atStart), AtStartCaption, UiTone.Tone.Warn if (atStart <= 0) else UiTone.Tone.Normal)


func _showMonthly(university: University, finances: Finances) -> void:
	upkeepRow.display(UpkeepKey, MoneyFormat.signed(-university.campus.upkeep()), "", UiTone.Tone.Bad)
	var interest: int = finances.interest()
	interestRow.display(InterestKey, MoneyFormat.signed(-interest), "", UiTone.Tone.Bad if (interest > 0) else UiTone.Tone.Normal)
	monthTotalRow.display(TotalKey, MoneyFormat.signed(-university.monthlyExpenses()), "", UiTone.Tone.Bad)


func _showCredit(finances: Finances) -> void:
	owedRow.display(OwedKey, MoneyFormat.short(finances.debt),
		OwedNoteFormat % [NumberFormat.percent(Finances.AnnualInterestRate), MoneyFormat.short(finances.interest())])
	creditLeftRow.display(CreditLeftKey, MoneyFormat.short(finances.availableCredit()), CreditLeftNoteFormat % MoneyFormat.short(Finances.CreditLimit))
	borrowButton.disabled = not finances.canBorrow()
	repayButton.disabled = not finances.canRepay()


func _showFees(university: University) -> void:
	var start: int = university.nextSemesterStart()
	feesTitle.text = FeesTitleFormat % [GameCalendar.PeriodNames[GameCalendar.period(start)], GameCalendar.weeksUntil(state.week(), start)]
	var fees: Fees = university.projectedFees()
	var prices: Prices = university.pricesAt(start)
	var enrolled: int = university.students.enrolled()
	var housedCount: int = university.housedAt(start)
	var mealPlanCount: int = university.mealPlansAt(start)
	tuitionRow.display(TuitionKeyFormat % NumberFormat.count(enrolled), MoneyFormat.signed(fees.tuition), EachFormat % MoneyFormat.full(prices.tuition), UiTone.Tone.Good)
	roomRow.display(RoomKeyFormat % NumberFormat.count(housedCount), MoneyFormat.signed(fees.room), EachFormat % MoneyFormat.full(prices.room), UiTone.Tone.Good)
	mealsRow.display(MealsKeyFormat % NumberFormat.count(mealPlanCount), MoneyFormat.signed(fees.meals), EachFormat % MoneyFormat.full(prices.mealPlan), UiTone.Tone.Good)
	feesTotalRow.display(TotalKey, MoneyFormat.signed(fees.total()), "", UiTone.Tone.Good)
	afterFeesRow.display(AfterFeesKey, ApproxFormat % MoneyFormat.short(university.cashAtSemesterStart() + fees.total()))
