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

@onready var titleLabel: Label = %Title
@onready var subLabel: Label = %Sub
@onready var statusPill: Label = %StatusPill
@onready var closeButton: Button = %CloseButton
@onready var demolishButton: Button = %DemolishButton
@onready var constructionPane: ConstructionPane = %ConstructionPane

var university: University
var building: Building


func _ready() -> void:
	closeButton.pressed.connect(func() -> void: CloseRequested.emit())
	demolishButton.pressed.connect(_demolish)
	constructionPane.PopoverWanted.connect(func(which: StringName) -> void: PopoverWanted.emit(which))


func setUniversity(shown: University) -> void:
	university = shown
	constructionPane.university = shown


## The selected building, or null to close.
func showBuilding(selected: Building) -> void:
	building = selected
	visible = (building != null)


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
	_showPane(_paneFor(building))


# Which pane shows: construction while it is going up, else its role's pane.
# Roles without a pane show the header and Demolish only.
func _paneFor(shown: Building) -> Control:
	if (shown.underConstruction):
		return constructionPane
	return null


func _showPane(pane: Control) -> void:
	constructionPane.visible = (pane == constructionPane)
	constructionPane.building = building


func _demolish() -> void:
	# The controller hears BuildingRemoved and clears the selection, which
	# closes this panel.
	university.campus.destroy(building)
