class_name HousingDropdown
extends PanelContainer
## Where students live: beds filled, who is off campus and the threshold that
## costs satisfaction, dorm by dorm with who fills them, and the dining load
## next to housing since only housed students eat on campus.

signal MoneyJumped

const TitleFormat: String = "Housing · %s"
const FilledFormat: String = "%s / %s"
const FilledCaption: String = "Beds filled"
const OffCampusCaptionFormat: String = "Off campus · %s"
const ThresholdCaption: String = "Discontent threshold"
const OpeningCaptionFormat: String = "Beds opening %s"
const PlusFormat: String = "+%s"
const OpensSuffixFormat: String = " · opens %s"
const BedsCellFormat: String = "%s / %s"
const BedsCellUnderConstruction: String = "— / %s"
const UpkeepUnderConstruction: String = "—"
const DinersKey: String = "Housed students eating"
const DinersNoteFormat: String = "recommended %s · limit %s"

@onready var title: Label = %Title
@onready var filledKpi: KpiView = %FilledKpi
@onready var offCampusKpi: KpiView = %OffCampusKpi
@onready var thresholdKpi: KpiView = %ThresholdKpi
@onready var openingKpi: KpiView = %OpeningKpi
@onready var dormsGrid: GridContainer = %Dorms
@onready var dinersRow: InfoRow = %DinersRow
@onready var loadLine: HBoxContainer = %LoadLine
@onready var diningLoadLine: DiningLoadLine = %DiningLoadLine
@onready var noDiningNote: Label = %NoDiningNote
@onready var moneyJump: Button = %MoneyJump

var university: University
# The header labels the dorms table starts with; rows follow them.
var _headerCount: int = 0


func _ready() -> void:
	_headerCount = dormsGrid.get_child_count()
	visibility_changed.connect(_rebuildDorms)
	moneyJump.pressed.connect(func() -> void: MoneyJumped.emit())


func setUniversity(shown: University) -> void:
	university = shown
	university.SemesterStarted.connect(func(_report: SemesterReport) -> void: _rebuildDorms())


func _process(_dt: float) -> void:
	if (university == null or not visible):
		return
	title.text = TitleFormat % GameCalendar.periodLabel(university.campus.month)
	_showKpis()
	_showDining()


func _showKpis() -> void:
	var housed: int = university.housed()
	var beds: int = university.campus.beds()
	filledKpi.display(FilledFormat % [NumberFormat.count(housed), NumberFormat.count(beds)], FilledCaption)
	var over: bool = university.hasProblem(Problem.Kind.HousingOverflow)
	offCampusKpi.display(NumberFormat.count(university.offCampus()),
		OffCampusCaptionFormat % NumberFormat.percent(university.offCampusShare()),
		UiTone.Tone.Warn if (over) else UiTone.Tone.Normal)
	thresholdKpi.display(NumberFormat.percent(UniversityRules.OverflowThreshold), ThresholdCaption)
	var start: int = university.nextSemesterStart()
	var opening: int = university.bedsOpeningNextSemester()
	openingKpi.visible = (opening > 0)
	openingKpi.display(PlusFormat % NumberFormat.count(opening), OpeningCaptionFormat % GameCalendar.periodLabel(start))


func _showDining() -> void:
	var meals: int = university.campus.meals()
	var housed: int = university.housed()
	if (meals == 0 and housed > 0):
		noDiningNote.visible = true
		dinersRow.visible = false
		loadLine.visible = false
		return
	noDiningNote.visible = false
	dinersRow.visible = true
	loadLine.visible = true
	dinersRow.display(DinersKey, NumberFormat.count(university.mealPlans()),
		DinersNoteFormat % [NumberFormat.count(meals), NumberFormat.count(UniversityRules.diningLimit(meals))])
	diningLoadLine.display(university)


func _rebuildDorms() -> void:
	if (university == null or not visible):
		return
	while (dormsGrid.get_child_count() > _headerCount):
		var row: Node = dormsGrid.get_child(dormsGrid.get_child_count() - 1)
		dormsGrid.remove_child(row)
		row.queue_free()
	for building: Building in university.campus.buildings:
		if (building.info.beds <= 0):
			continue
		var nameText: String = building.info.name
		if (building.underConstruction):
			nameText += OpensSuffixFormat % GameCalendar.periodLabel(building.opensAtMonth)
		_addCell(nameText, &"RowValue")
		var bedsText: String = (BedsCellUnderConstruction % NumberFormat.count(building.info.beds)) if (building.underConstruction) \
			else (BedsCellFormat % [NumberFormat.count(university.residentsOf(building)), NumberFormat.count(building.info.beds)])
		_addCell(bedsText, &"RowKey")
		_addCell(UpkeepUnderConstruction if (building.underConstruction) else MoneyFormat.short(building.info.upkeep), &"RowKey")


func _addCell(text: String, variation: StringName) -> void:
	var cell: Label = Label.new()
	cell.text = text
	cell.theme_type_variation = variation
	dormsGrid.add_child(cell)
