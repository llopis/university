class_name ActionBar
extends HBoxContainer
## The two actions in the bottom-left corner: Build (B) opens the build panel,
## Demolish (X) arms the destroy tool. They only announce presses; the Hud and
## the controller own what is open and armed, and say so back.

signal BuildPressed
signal DemolishPressed

@onready var buildButton: Button = %BuildButton
@onready var demolishButton: Button = %DemolishButton


func _ready() -> void:
	buildButton.pressed.connect(func() -> void: BuildPressed.emit())
	demolishButton.pressed.connect(func() -> void: DemolishPressed.emit())


func showBuildOpen(open: bool) -> void:
	buildButton.set_pressed_no_signal(open)


func showTool(armed: BuildController.Tool) -> void:
	demolishButton.set_pressed_no_signal(armed == BuildController.Tool.Destroy)
