class_name SemesterPopup
extends Control
## The report shown at every semester start: admissions (fall only), the
## campus's fees, housing, dining, reputation and satisfaction, and what
## opened. Shown by Hud.showReport, which pauses the game around it.

signal Continued

const TitleFormat: String = "%s begins"
const SubFall: String = "Admissions resolved · buildings opened · fees collected"
const SubSpring: String = "Buildings opened · fees collected"
const ApplicantsKey: String = "Applicants"
const AdmittedKey: String = "Admitted"
const OpenSeatsNoteFormat: String = "of %s open seats"
const GradeKey: String = "Entry grade"
const GradeFormat: String = "%.2f"
const Nothing: String = "—"
const GraduatedKey: String = "Graduated"
const FeesKey: String = "Fees collected"
const OnCampusKey: String = "On campus"
const OnCampusFormat: String = "%s / %s beds"
const OffCampusKey: String = "Off campus"
const OffCampusFormat: String = "%s · %s"
const AboveThresholdPill: String = "above threshold"
const DiningKey: String = "Dining"
const CrowdedPill: String = "crowded"
const CantEatPill: String = "can't eat"
const ReputationKey: String = "Reputation"
const SatisfactionKey: String = "Satisfaction"
const ChangeFormat: String = "%.0f (%+.0f)"
const OpenedKey: String = "Opened"
const OpenedSeparator: String = ", "

@onready var title: Label = %Title
@onready var titleHelp: HelpIcon = %Help
@onready var applicantsRow: InfoRow = %ApplicantsRow
@onready var admittedRow: InfoRow = %AdmittedRow
@onready var gradeRow: InfoRow = %GradeRow
@onready var graduatedRow: InfoRow = %GraduatedRow
@onready var springNote: Label = %SpringNote
@onready var feesRow: InfoRow = %FeesRow
@onready var onCampusRow: InfoRow = %OnCampusRow
@onready var offCampusRow: InfoRow = %OffCampusRow
@onready var diningRow: InfoRow = %DiningRow
@onready var reputationRow: InfoRow = %ReputationRow
@onready var satisfactionRow: InfoRow = %SatisfactionRow
@onready var openedRow: InfoRow = %OpenedRow
@onready var continueButton: Button = %ContinueButton


func _ready() -> void:
	continueButton.pressed.connect(dismiss)


func showReport(report: SemesterReport) -> void:
	title.text = TitleFormat % GameCalendar.periodLabel(report.month)
	titleHelp.tooltip_text = SubFall if (report.isFall) else SubSpring
	_showAdmissions(report)
	_showCampus(report)
	visible = true


func _showAdmissions(report: SemesterReport) -> void:
	applicantsRow.visible = report.isFall
	admittedRow.visible = report.isFall
	gradeRow.visible = report.isFall
	graduatedRow.visible = report.isFall
	springNote.visible = not report.isFall
	if (not report.isFall):
		return
	applicantsRow.display(ApplicantsKey, NumberFormat.count(report.applicants))
	admittedRow.display(AdmittedKey, NumberFormat.count(report.admitted), OpenSeatsNoteFormat % NumberFormat.count(report.openSeats))
	gradeRow.display(GradeKey, (GradeFormat % report.entryGrade) if (report.admitted > 0) else Nothing)
	graduatedRow.display(GraduatedKey, NumberFormat.count(report.graduated))


func _showCampus(report: SemesterReport) -> void:
	feesRow.display(FeesKey, MoneyFormat.signed(report.totalFees()), "", UiTone.Tone.Good)
	onCampusRow.display(OnCampusKey, OnCampusFormat % [NumberFormat.count(report.housed), NumberFormat.count(report.beds)])
	_showOffCampus(report)
	_showDining(report)
	_showChange(reputationRow, ReputationKey, report.reputation, report.reputationChange)
	_showChange(satisfactionRow, SatisfactionKey, report.satisfaction, report.satisfactionChange)
	openedRow.display(OpenedKey, OpenedSeparator.join(report.opened) if (not report.opened.is_empty()) else Nothing)


func _showOffCampus(report: SemesterReport) -> void:
	var share: float = report.offCampusShare()
	var over: bool = share > UniversityRules.OverflowThreshold
	offCampusRow.display(OffCampusKey, OffCampusFormat % [NumberFormat.count(report.offCampus()), NumberFormat.percent(share)],
		"", UiTone.Tone.Warn if (over) else UiTone.Tone.Normal)
	offCampusRow.showPill(AboveThresholdPill if (over) else "", UiTone.Tone.Warn)


func _showDining(report: SemesterReport) -> void:
	var unfedCount: int = report.unfed()
	var crowded: bool = report.diningLoad > UniversityRules.RecommendedLoad
	var tone: UiTone.Tone = UiTone.Tone.Bad if (unfedCount > 0) else (UiTone.Tone.Warn if (crowded) else UiTone.Tone.Normal)
	diningRow.display(DiningKey, NumberFormat.percent(report.diningLoad), "", tone)
	diningRow.showPill(CantEatPill if (unfedCount > 0) else (CrowdedPill if (crowded) else ""),
		UiTone.Tone.Bad if (unfedCount > 0) else UiTone.Tone.Warn)


func _showChange(row: InfoRow, key: String, value: float, change: float) -> void:
	var tone: UiTone.Tone = UiTone.Tone.Good if (change > 0.0) else (UiTone.Tone.Bad if (change < 0.0) else UiTone.Tone.Normal)
	row.display(key, ChangeFormat % [value, change], "", tone)


## The Continue path: hides the popup and hands the pause it interrupted back.
## Public so Esc, in Hud._unhandled_input, can dismiss the popup the same way.
func dismiss() -> void:
	visible = false
	Continued.emit()
