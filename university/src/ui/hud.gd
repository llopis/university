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
@onready var studentsDropdown: StudentsDropdown = %StudentsDropdown
@onready var reputationDropdown: ReputationDropdown = %ReputationDropdown
@onready var housingDropdown: HousingDropdown = %HousingDropdown
@onready var moneyDropdown: MoneyDropdown = %MoneyDropdown
@onready var semesterPopup: SemesterPopup = %SemesterPopup

var state: GameState
var camera: GameCamera
var controller: BuildController

var _popovers: Dictionary[StringName, Control]
var _open: StringName = None
# The pause state from before the first of a run of semester reports, so
# Continue hands it back rather than whatever showReport itself set.
var _pausedBefore: bool = false


func _ready() -> void:
	_popovers = {
		&"gamemenu": gameMenu, &"unimenu": universityMenu, &"students": studentsDropdown,
		&"reputation": reputationDropdown, &"housing": housingDropdown, &"money": moneyDropdown,
	}
	topBar.GameMenuPressed.connect(toggle.bind(&"gamemenu"))
	topBar.UniversityMenuPressed.connect(toggle.bind(&"unimenu"))
	topBar.StudentsPressed.connect(toggle.bind(&"students"))
	topBar.HousingPressed.connect(toggle.bind(&"housing"))
	topBar.MoneyPressed.connect(toggle.bind(&"money"))
	topBar.ReputationPressed.connect(toggle.bind(&"reputation"))
	gameMenu.Chosen.connect(closePopover)
	universityMenu.BuildingChosen.connect(_showBuilding)
	universityMenu.ReputationChosen.connect(openPopover.bind(&"reputation"))
	universityMenu.HousingChosen.connect(openPopover.bind(&"housing"))
	universityMenu.FinancesChosen.connect(openPopover.bind(&"money"))
	studentsDropdown.ReputationJumped.connect(openPopover.bind(&"reputation"))
	studentsDropdown.HousingJumped.connect(openPopover.bind(&"housing"))
	reputationDropdown.HousingJumped.connect(openPopover.bind(&"housing"))
	housingDropdown.MoneyJumped.connect(openPopover.bind(&"money"))


func setup(gameState: GameState, gameCamera: GameCamera, buildController: BuildController) -> void:
	state = gameState
	camera = gameCamera
	controller = buildController
	topBar.state = state
	universityMenu.university = state.university
	studentsDropdown.setUniversity(state.university)
	reputationDropdown.university = state.university
	housingDropdown.setUniversity(state.university)
	moneyDropdown.setState(state)
	controller.NothingToCancel.connect(openPopover.bind(&"gamemenu"))
	state.university.SemesterStarted.connect(showReport)
	semesterPopup.Continued.connect(_onContinued)
	semesterPopup.HousingWanted.connect(_onHousingWanted)


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


## Shows a semester's report, pausing the game. Several in a row show the
## latest; the pause remembered is the one from before the first of them.
## Runs mid-tick (University.SemesterStarted fires before the month's bill),
## so this must only pause and show, never save, load or change state.
func showReport(report: SemesterReport) -> void:
	if (not semesterPopup.visible):
		_pausedBefore = state.paused
	state.setPaused(true)
	closePopover()
	semesterPopup.showReport(report)


## Shows the latest semester report, for the console.
func showLatestReport() -> void:
	var reports: Array[SemesterReport] = state.university.reports
	if (not reports.is_empty()):
		showReport(reports[reports.size() - 1])


func _onContinued() -> void:
	state.setPaused(_pausedBefore)


## The player chose to inspect housing, so the clock stays paused rather than
## picking back up at whatever speed was running before the popup.
func _onHousingWanted() -> void:
	state.setPaused(true)
	openPopover(&"housing")


func _unhandled_input(event: InputEvent) -> void:
	if (semesterPopup.visible):
		# The popup is modal: Continue, Esc and "Look at housing" are the ways
		# out, and Space does nothing while it is up.
		if (event.is_action_pressed(&"ExitGame")):
			semesterPopup.dismiss()
			get_viewport().set_input_as_handled()
		elif (event.is_action_pressed(&"TogglePause")):
			get_viewport().set_input_as_handled()
		return
	if (event.is_action_pressed(&"ExitGame") and closePopover()):
		get_viewport().set_input_as_handled()
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		# The world gets the click too: closing a popover never swallows it.
		closePopover()
