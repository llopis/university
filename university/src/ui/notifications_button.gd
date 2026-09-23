class_name NotificationsButton
extends Button
## The bell at the top left of the play area: its badge counts what is wrong
## right now, and pressing it opens the notifications panel.

@onready var badge: PanelContainer = %Badge
@onready var countLabel: Label = %Count


func setCount(count: int) -> void:
	badge.visible = (count > 0)
	countLabel.text = str(count)
