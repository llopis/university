class_name DiningPane
extends VBoxContainer
## The dining load against every open dining hall's capacity: meal plans sold,
## the load itself and who can't eat, then all dining halls' meal plan fees
## against this hall's upkeep. Follows the pane pattern: filled every
## `_process` while visible; no list of its own to rebuild.

signal BuildWanted(category: String)

const PlansCaption: String = "Meal plans"
const LoadCaption: String = "Load"
const UnfedCaption: String = "Can't eat"
const LoadNoteFormat: String = "All dining halls, housed students. Up to %s diners it is comfortable. Past that it gets crowded and satisfaction drops. Past %s (%s) the rest can't eat: they buy no meal plan and satisfaction drops harder."
const MealFeesKey: String = "Meal plan fees per semester · all halls"
const UpkeepKey: String = "Upkeep and staff"

@onready var plansKpi: KpiView = %PlansKpi
@onready var loadKpi: KpiView = %LoadKpi
@onready var unfedKpi: KpiView = %UnfedKpi
@onready var loadLine: DiningLoadLine = %LoadLine
@onready var loadHelp: HelpIcon = %LoadHelp
@onready var mealFeesRow: InfoRow = %MealFeesRow
@onready var upkeepRow: InfoRow = %UpkeepRow
@onready var buildJump: Button = %BuildJump

var university: University
var building: Building


func _ready() -> void:
	buildJump.pressed.connect(func() -> void: BuildWanted.emit(building.info.category))


func setUniversity(shown: University) -> void:
	university = shown


func _process(_dt: float) -> void:
	if (university == null or building == null or not visible):
		return
	var info: BuildingInfo = building.info
	var campus: Campus = university.campus
	plansKpi.display(NumberFormat.count(university.mealPlans()), PlansCaption)
	loadKpi.display(NumberFormat.percent(university.diningLoad()), LoadCaption, DiningLoadLine.toneFor(university))
	var unfedCount: int = university.unfed()
	unfedKpi.display(NumberFormat.count(unfedCount), UnfedCaption, UiTone.Tone.Bad if (unfedCount > 0) else UiTone.Tone.Normal)
	loadLine.display(university)
	var meals: int = campus.meals()
	loadHelp.tooltip_text = LoadNoteFormat % [NumberFormat.count(meals), NumberFormat.count(UniversityRules.diningLimit(meals)), NumberFormat.percent(UniversityRules.DiningHardLimit)]
	mealFeesRow.display(MealFeesKey, MoneyFormat.signed(university.feesNow().meals), "", UiTone.Tone.Good)
	upkeepRow.display(UpkeepKey, BuildingText.upkeep(info), "", UiTone.Tone.Bad)
