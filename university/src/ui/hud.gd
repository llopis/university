class_name Hud
extends Control
## The HUD's root: the top bar, its popovers (one open at a time) and the
## semester popup. It carries the shared theme. Everything it shows is read
## from the game state it is set up with. A click on the world closes the open
## popover and still reaches the world; Esc closes it first of all.

const None: StringName = &""

@onready var topBar: TopBar = %TopBar
@onready var gameMenu: GameMenu = %GameMenu
@onready var universityMenu: UniversityMenu = %UniversityMenu

var state: GameState
var camera: GameCamera
var controller: BuildController

var _popovers: Dictionary[StringName, Control]
var _open: StringName = None


func _ready() -> void:
	_popovers = {&"gamemenu": gameMenu, &"unimenu": universityMenu}
	topBar.GameMenuPressed.connect(toggle.bind(&"gamemenu"))
	topBar.UniversityMenuPressed.connect(toggle.bind(&"unimenu"))
	gameMenu.Chosen.connect(closePopover)
	universityMenu.BuildingChosen.connect(_showBuilding)


func setup(gameState: GameState, gameCamera: GameCamera, buildController: BuildController) -> void:
	state = gameState
	camera = gameCamera
	controller = buildController
	topBar.state = state
	universityMenu.university = state.university
	controller.NothingToCancel.connect(openPopover.bind(&"gamemenu"))


func popoverOpen() -> StringName:
	return _open


func toggle(which: StringName) -> void:
	if (_open == which):
		closePopover()
	else:
		openPopover(which)


func openPopover(which: StringName) -> void:
	closePopover()
	if (not _popovers.has(which)):
		return
	_popovers[which].visible = true
	topBar.setOpen(which, true)
	_open = which


## Closes whichever popover is open. Answers whether one was.
func closePopover() -> bool:
	if (_open == None):
		return false
	_popovers[_open].visible = false
	topBar.setOpen(_open, false)
	_open = None
	return true


func _showBuilding(building: Building) -> void:
	closePopover()
	controller.select(building)
	camera.setTarget(building.pos)


func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed(&"ExitGame") and closePopover()):
		get_viewport().set_input_as_handled()
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		# The world gets the click too: closing a popover never swallows it.
		closePopover()
