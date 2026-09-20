class_name InfoPanel
extends PanelContainer
## What is known about the selected building: for now, its name. Hidden while
## nothing is selected.

@onready var nameLabel: Label = %NameLabel


func showBuilding(building: Building) -> void:
	visible = (building != null)
	if (building != null):
		nameLabel.text = building.info.name
