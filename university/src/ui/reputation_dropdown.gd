class_name ReputationDropdown
extends PanelContainer
## Why reputation is where it is and where it is heading: its target, half the
## latest intake's grade and half this year's satisfaction, and satisfaction's
## penalties.

signal HousingJumped

const TitleFormat: String = "Reputation · %.0f"
const ScoreFormat: String = "%.0f"
const GradeFormat: String = "%.2f"
const PenaltyFormat: String = "−%.0f"
const NoPenalty: String = "0"
const RateNoteFormat: String = "Reputation moves %s of the way to its target each fall. Reputation sets how many apply; price does too: see the Admissions Office."
const SatisfactionFormat: String = "Satisfaction · %.0f"
const OffCampusFormat: String = "Off campus (%s)"
const CrowdedFormat: String = "Dining (%s)"
const AfterFormat: String = "≈ %.0f"
const ReputationCaption: String = "Reputation"
const TargetLabel: String = "Target"
const AfterCaptionFormat: String = "After %s"
const GradeRowKey: String = "Latest intake's entry grade"
const GradeScoreNoteFormat: String = "counts as %.0f"
const YearSatisfactionKey: String = "Satisfaction this year"
const BaselineKey: String = "Baseline"
const UnfedKey: String = "Can't eat"

@onready var title: Label = %Title
@onready var targetHelp: HelpIcon = %TargetHelp
@onready var reputationKpi: KpiView = %ReputationKpi
@onready var targetKpi: KpiView = %TargetKpi
@onready var afterKpi: KpiView = %AfterKpi
@onready var gradeRow: InfoRow = %GradeRow
@onready var yearSatisfactionRow: InfoRow = %YearSatisfactionRow
@onready var targetRow: InfoRow = %TargetRow
@onready var satisfactionTitle: Label = %SatisfactionTitle
@onready var baselineRow: InfoRow = %BaselineRow
@onready var housingPenaltyRow: InfoRow = %HousingPenaltyRow
@onready var crowdingPenaltyRow: InfoRow = %CrowdingPenaltyRow
@onready var unfedPenaltyRow: InfoRow = %UnfedPenaltyRow
@onready var housingJump: Button = %HousingJump

var university: University


func _ready() -> void:
	targetHelp.tooltip_text = RateNoteFormat % NumberFormat.percent(UniversityRules.ReputationRate)
	housingJump.pressed.connect(func() -> void: HousingJumped.emit())


func _process(_dt: float) -> void:
	if (university == null or not visible):
		return
	var target: float = university.reputationTarget()
	var after: float = UniversityRules.nextReputation(university.reputation, target)
	title.text = TitleFormat % university.reputation
	reputationKpi.display(ScoreFormat % university.reputation, ReputationCaption)
	targetKpi.display(ScoreFormat % target, TargetLabel, UiTone.trend(university.reputation, target))
	afterKpi.display(AfterFormat % after, AfterCaptionFormat % GameCalendar.periodLabel(university.nextFallStart()))
	gradeRow.display(GradeRowKey, GradeFormat % university.lastIntakeGrade,
		GradeScoreNoteFormat % UniversityRules.gradeScore(university.lastIntakeGrade))
	yearSatisfactionRow.display(YearSatisfactionKey, ScoreFormat % university.yearSatisfaction())
	targetRow.display(TargetLabel, ScoreFormat % target)
	var now: Satisfaction = university.satisfactionNow()
	satisfactionTitle.text = SatisfactionFormat % now.total()
	baselineRow.display(BaselineKey, ScoreFormat % now.base)
	housingPenaltyRow.display(OffCampusFormat % NumberFormat.percent(university.offCampusShare()), _penalty(now.housing), "", _penaltyTone(now.housing))
	var dining: float = university.diningLoad()
	crowdingPenaltyRow.display(CrowdedFormat % NumberFormat.percent(dining), _penalty(now.crowding), "", _penaltyTone(now.crowding))
	unfedPenaltyRow.display(UnfedKey, _penalty(now.unfed), "", _penaltyTone(now.unfed))


static func _penalty(points: float) -> String:
	return PenaltyFormat % points if (points > 0.0) else NoPenalty


static func _penaltyTone(points: float) -> UiTone.Tone:
	return UiTone.Tone.Bad if (points > 0.0) else UiTone.Tone.Normal
