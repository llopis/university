class_name BuildMenu
extends VBoxContainer
## The Build button in the bottom-left corner and the list it opens: one entry
## per building type, then Destroy. It only announces what was chosen and
## shows what it is told is armed; the controller owns the tool. The entries
## are made in code because how many there are is data.

signal BuildingChosen(info: BuildingInfo)
signal DestroyChosen
## The list was closed, which puts any tool away.
signal Closed

@onready var options: PanelContainer = %Options
@onready var optionList: VBoxContainer = %OptionList
@onready var destroyButton: Button = %DestroyButton
@onready var buildButton: Button = %BuildButton

var _buttons: Dictionary[BuildingInfo, Button]


func _ready() -> void:
	buildButton.toggled.connect(_onBuildToggled)
	destroyButton.pressed.connect(func() -> void: DestroyChosen.emit())


func populate(infos: Array[BuildingInfo]) -> void:
	for info: BuildingInfo in infos:
		var button: Button = Button.new()
		button.text = info.name
		button.toggle_mode = true
		# Keyboard focus would make the arrow keys walk the entries as well as
		# pan the camera, and Space re-press whichever entry has the ring.
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = destroyButton.custom_minimum_size
		button.pressed.connect(func() -> void: BuildingChosen.emit(info))
		optionList.add_child(button)
		optionList.move_child(button, destroyButton.get_index())
		_buttons[info] = button


## Shows which entry is armed. Called on every tool change, so a press that
## toggled a button the wrong way is put right here.
func showTool(armed: BuildController.Tool, info: BuildingInfo) -> void:
	destroyButton.set_pressed_no_signal(armed == BuildController.Tool.Destroy)
	for entry: BuildingInfo in _buttons:
		_buttons[entry].set_pressed_no_signal(armed == BuildController.Tool.Place and entry == info)


func _onBuildToggled(open: bool) -> void:
	options.visible = open
	if (not open):
		Closed.emit()
