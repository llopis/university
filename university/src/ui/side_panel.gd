class_name SidePanel
extends PanelContainer
## The docked panel on the right: the selected building. It opens on selection
## and closes with it. Its pane follows the building's role, or its
## construction while it is still going up. Demolish destroys the building
## under Campus.destroy's refund rule. It owns no state: everything is re-read
## each frame, so a building opening mid-view swaps its pane by itself.

signal CloseRequested
signal PopoverWanted(which: StringName)
signal BuildWanted(category: String)
signal BuildingWanted(building: Building)

const SubFormat: String = "%s · %s"
const OpensFormat: String = "Under construction · opens %s"
const DemolishText: String = "Demolish"
const DemolishRefundFormat: String = "Demolish · refund %s"
const DemolishRefundNoteFormat: String = "Demolishing it before it opens refunds the full %s. Once it has opened, nothing comes back."
const DemolishNoRefundNote: String = "Demolishing an open building refunds nothing."

@onready var titleLabel: Label = %Title
@onready var subLabel: Label = %Sub
@onready var statusPill: Label = %StatusPill
@onready var closeButton: Button = %CloseButton
@onready var demolishButton: Button = %DemolishButton
@onready var demolishHelp: HelpIcon = %DemolishHelp
@onready var constructionPane: ConstructionPane = %ConstructionPane
@onready var admissionsPane: AdmissionsPane = %AdmissionsPane
@onready var academicPane: AcademicPane = %AcademicPane
@onready var dormPane: DormPane = %DormPane
@onready var diningPane: DiningPane = %DiningPane

var university: University
var building: Building


func _ready() -> void:
	closeButton.pressed.connect(func() -> void: CloseRequested.emit())
	demolishButton.pressed.connect(_demolish)
	constructionPane.PopoverWanted.connect(func(which: StringName) -> void: PopoverWanted.emit(which))
	admissionsPane.PopoverWanted.connect(func(which: StringName) -> void: PopoverWanted.emit(which))
	academicPane.PopoverWanted.connect(func(which: StringName) -> void: PopoverWanted.emit(which))
	academicPane.BuildWanted.connect(func(category: String) -> void: BuildWanted.emit(category))
	academicPane.BuildingWanted.connect(func(selected: Building) -> void: BuildingWanted.emit(selected))
	dormPane.PopoverWanted.connect(func(which: StringName) -> void: PopoverWanted.emit(which))
	diningPane.BuildWanted.connect(func(category: String) -> void: BuildWanted.emit(category))


func setUniversity(shown: University) -> void:
	university = shown
	constructionPane.university = shown
	admissionsPane.setUniversity(shown)
	academicPane.setUniversity(shown)
	dormPane.setUniversity(shown)
	diningPane.setUniversity(shown)


## The selected building, or null to close.
func showBuilding(selected: Building) -> void:
	building = selected
	visible = (building != null)
	if (selected == null):
		# Otherwise the last pane stays visible with a stale building.
		_showPane(null)


func _process(_dt: float) -> void:
	if (university == null or building == null):
		return
	var info: BuildingInfo = building.info
	titleLabel.text = info.name
	var holds: String = BuildingText.holds(info)
	subLabel.text = (SubFormat % [info.category, holds]) if (holds != "") else info.category
	statusPill.visible = building.underConstruction
	statusPill.text = OpensFormat % GameCalendar.periodLabel(building.opensAtMonth)
	var refund: int = university.campus.refundFor(building)
	demolishButton.text = (DemolishRefundFormat % MoneyFormat.short(refund)) if (refund > 0) else DemolishText
	demolishHelp.tooltip_text = (DemolishRefundNoteFormat % MoneyFormat.short(refund)) if (building.underConstruction) else DemolishNoRefundNote
	_showPane(_paneFor(building))


# Which pane shows: construction while it is going up, else its role's pane.
# Roles without a pane show the header and Demolish only.
func _paneFor(shown: Building) -> Control:
	if (shown.underConstruction):
		return constructionPane
	match shown.info.role():
		BuildingInfo.Role.Academic:
			return academicPane
		BuildingInfo.Role.Housing:
			return dormPane
		BuildingInfo.Role.Dining:
			return diningPane
		BuildingInfo.Role.Admissions:
			return admissionsPane
	return null


func _showPane(pane: Control) -> void:
	var panes: Array[Control] = [constructionPane, admissionsPane, academicPane, dormPane, diningPane]
	for candidate: Control in panes:
		candidate.visible = (candidate == pane)
	constructionPane.building = building
	admissionsPane.building = building
	academicPane.building = building
	dormPane.building = building
	diningPane.building = building


func _demolish() -> void:
	# The controller hears BuildingRemoved and clears the selection, which
	# closes this panel.
	university.campus.destroy(building)
