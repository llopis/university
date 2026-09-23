class_name ConstructionPane
extends VBoxContainer
## What opening changes for a building still under construction: the capacity
## it adds, the effect on who lives off campus (housing only), its upkeep from
## then on, and the refund rule while it is still going up. Demolish itself
## lives in SidePanel; this only jumps to the housing or students pane.

signal PopoverWanted(which: StringName)

const CapacityKeyBeds: String = "Beds"
const CapacityKeySeats: String = "Seats"
const CapacityKeyDiners: String = "Diners"
const CapacityValueFormat: String = "+%s"
const BeforeAfterFormat: String = "%s → %s"
const OffCampusKey: String = "Off campus"
const UnderThresholdFormat: String = "%s → %s, under the threshold"
const OverThresholdFormat: String = "%s → %s, still above the threshold"
const UpkeepKey: String = "Upkeep"
const UpkeepValueFormat: String = "%s / mo"
const UpkeepNote: String = "from then on"
const RefundNoteFormat: String = "Demolishing it before it opens refunds the full %s. Once it has opened, nothing comes back."
const HousingJumpText: String = "All housing →"
const StudentsJumpText: String = "All students →"

@onready var capacityRow: InfoRow = %CapacityRow
@onready var offCampusRow: InfoRow = %OffCampusRow
@onready var upkeepRow: InfoRow = %UpkeepRow
@onready var refundNote: Label = %RefundNote
@onready var jump: Button = %Jump

var university: University
var building: Building


func _ready() -> void:
	jump.pressed.connect(_onJumpPressed)


func _process(_dt: float) -> void:
	if (university == null or building == null or not visible):
		return
	var info: BuildingInfo = building.info
	_showCapacity(info)
	_showOffCampus(info)
	_showUpkeep(info)
	refundNote.text = RefundNoteFormat % MoneyFormat.short(university.campus.refundFor(building))
	_showJump(info.role())


func _showCapacity(info: BuildingInfo) -> void:
	var added: int = info.capacity()
	capacityRow.visible = (added > 0)
	if (added == 0):
		return
	var before: int = university.campus.capacityFor(info.role())
	capacityRow.display(_capacityKey(info.role()), CapacityValueFormat % NumberFormat.count(added),
		BeforeAfterFormat % [NumberFormat.count(before), NumberFormat.count(before + added)])


func _capacityKey(role: BuildingInfo.Role) -> String:
	match role:
		BuildingInfo.Role.Housing:
			return CapacityKeyBeds
		BuildingInfo.Role.Academic:
			return CapacityKeySeats
		BuildingInfo.Role.Dining:
			return CapacityKeyDiners
	return ""


func _showOffCampus(info: BuildingInfo) -> void:
	offCampusRow.visible = (info.role() == BuildingInfo.Role.Housing)
	if (not offCampusRow.visible):
		return
	var afterBeds: int = university.campus.beds() + info.beds
	var before: int = university.offCampus()
	var after: int = university.offCampusWith(afterBeds)
	var beforeShare: float = university.offCampusShare()
	var afterShare: float = university.offCampusShareWith(afterBeds)
	var noteFormat: String = UnderThresholdFormat if (afterShare <= UniversityRules.OverflowThreshold) else OverThresholdFormat
	offCampusRow.display(OffCampusKey, BeforeAfterFormat % [NumberFormat.count(before), NumberFormat.count(after)],
		noteFormat % [NumberFormat.percent(beforeShare), NumberFormat.percent(afterShare)])


func _showUpkeep(info: BuildingInfo) -> void:
	upkeepRow.display(UpkeepKey, UpkeepValueFormat % MoneyFormat.signed(-info.upkeep), UpkeepNote, UiTone.Tone.Bad)


func _showJump(role: BuildingInfo.Role) -> void:
	match role:
		BuildingInfo.Role.Housing, BuildingInfo.Role.Dining:
			jump.visible = true
			jump.text = HousingJumpText
		BuildingInfo.Role.Academic:
			jump.visible = true
			jump.text = StudentsJumpText
		_:
			jump.visible = false


func _onJumpPressed() -> void:
	match building.info.role():
		BuildingInfo.Role.Housing, BuildingInfo.Role.Dining:
			PopoverWanted.emit(&"housing")
		BuildingInfo.Role.Academic:
			PopoverWanted.emit(&"students")
