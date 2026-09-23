class_name InfoPanel
extends PanelContainer
## What is known about the selected building: its name and whether it is
## still under construction or already open. Hidden while nothing is selected.

const OpenText: String = "Open"
const ConstructionText: String = "Under construction — opens %s"

@onready var nameLabel: Label = %NameLabel
@onready var statusLabel: Label = %StatusLabel


func showBuilding(building: Building) -> void:
	visible = (building != null)
	if (building != null):
		nameLabel.text = building.info.name
		statusLabel.text = (ConstructionText % GameCalendar.periodLabel(building.opensAtMonth)) if (building.underConstruction) else OpenText
