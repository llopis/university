class_name DormPane
extends VBoxContainer
## One dorm against the whole housing pool: beds filled and who lives off
## campus, then this dorm's room fees against its upkeep. Follows the pane
## pattern: filled every `_process` while visible; no list of its own to
## rebuild.

signal PopoverWanted(which: StringName)

const FilledFormat: String = "%s / %s"
const FilledCaption: String = "Beds filled"
const OffCampusCaptionFormat: String = "Off campus · %s"
const AllDormsKey: String = "All dorms"
const AllDormsFormat: String = "%s / %s beds"
const OpeningKeyFormat: String = "Opening %s"
const OpeningFormat: String = "+%s beds"
const HousingNoteFormat: String = "With more students than beds, the rest live off campus and pay tuition only. Past %s off campus, satisfaction drops."
const RoomFeesKey: String = "Room fees per semester"
const RoomFeesNoteFormat: String = "%s × %s"
const UpkeepKey: String = "Upkeep and staff"
const UpkeepValueFormat: String = "%s / mo"

@onready var filledKpi: KpiView = %FilledKpi
@onready var offCampusKpi: KpiView = %OffCampusKpi
@onready var allDormsRow: InfoRow = %AllDormsRow
@onready var openingRow: InfoRow = %OpeningRow
@onready var housingNote: Label = %HousingNote
@onready var roomFeesRow: InfoRow = %RoomFeesRow
@onready var upkeepRow: InfoRow = %UpkeepRow
@onready var housingJump: Button = %HousingJump

var university: University
var building: Building


func _ready() -> void:
	housingJump.pressed.connect(func() -> void: PopoverWanted.emit(&"housing"))


func setUniversity(shown: University) -> void:
	university = shown


func _process(_dt: float) -> void:
	if (university == null or building == null or not visible):
		return
	var info: BuildingInfo = building.info
	var campus: Campus = university.campus
	var residents: int = university.residentsOf(building)
	filledKpi.display(FilledFormat % [NumberFormat.count(residents), NumberFormat.count(info.beds)], FilledCaption)
	var over: bool = university.hasProblem(Problem.Kind.HousingOverflow)
	offCampusKpi.display(NumberFormat.count(university.offCampus()),
		OffCampusCaptionFormat % NumberFormat.percent(university.offCampusShare()),
		UiTone.Tone.Warn if (over) else UiTone.Tone.Normal)
	allDormsRow.display(AllDormsKey, AllDormsFormat % [NumberFormat.count(university.housed()), NumberFormat.count(campus.beds())])
	var opening: int = university.bedsOpeningNextSemester()
	openingRow.visible = (opening > 0)
	openingRow.display(OpeningKeyFormat % GameCalendar.periodLabel(university.nextSemesterStart()), OpeningFormat % NumberFormat.count(opening))
	housingNote.text = HousingNoteFormat % NumberFormat.percent(UniversityRules.OverflowThreshold)
	roomFeesRow.display(RoomFeesKey, MoneyFormat.signed(university.roomFeesOf(building)),
		RoomFeesNoteFormat % [NumberFormat.count(residents), MoneyFormat.full(university.policy.current.room)], UiTone.Tone.Good)
	upkeepRow.display(UpkeepKey, UpkeepValueFormat % MoneyFormat.signed(-info.upkeep), "", UiTone.Tone.Bad)
