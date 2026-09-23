class_name Hud
extends Control
## The HUD's root: the top bar, its popovers (one open at a time) and the
## semester popup. It carries the shared theme. Everything it shows is read
## from the game state it is set up with. A click on the world closes the open
## popover and still reaches the world; Esc closes it first of all.

const None: StringName = &""
const PaneConstruction: StringName = &"construction"
const PaneAdmissions: StringName = &"admissions"
const PaneAcademic: StringName = &"academic"
const PaneDorm: StringName = &"dorm"
const PaneDining: StringName = &"dining"
const PopoverBuild: StringName = &"build"
const PopoverHousing: StringName = &"housing"
const PopoverMoney: StringName = &"money"
const PopoverUniversity: StringName = &"unimenu"
# The alerts' left/right offsets keep this clear of the side panel's edge.
const AlertsMargin: float = 16.0

@onready var campusMarkers: CampusMarkers = %CampusMarkers
@onready var topBar: TopBar = %TopBar
@onready var sidePanel: SidePanel = %SidePanel
@onready var alerts: Alerts = %Alerts
@onready var actionBar: ActionBar = %ActionBar
@onready var gameMenu: GameMenu = %GameMenu
@onready var universityMenu: UniversityMenu = %UniversityMenu
@onready var studentsDropdown: StudentsDropdown = %StudentsDropdown
@onready var reputationDropdown: ReputationDropdown = %ReputationDropdown
@onready var housingDropdown: HousingDropdown = %HousingDropdown
@onready var moneyDropdown: MoneyDropdown = %MoneyDropdown
@onready var buildPanel: BuildPanel = %BuildPanel
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
		&"gamemenu": gameMenu, PopoverUniversity: universityMenu, &"students": studentsDropdown,
		&"reputation": reputationDropdown, PopoverHousing: housingDropdown, PopoverMoney: moneyDropdown,
		PopoverBuild: buildPanel,
	}
	topBar.GameMenuPressed.connect(toggle.bind(&"gamemenu"))
	topBar.UniversityMenuPressed.connect(toggle.bind(PopoverUniversity))
	topBar.StudentsPressed.connect(toggle.bind(&"students"))
	topBar.HousingPressed.connect(toggle.bind(PopoverHousing))
	topBar.MoneyPressed.connect(toggle.bind(PopoverMoney))
	topBar.ReputationPressed.connect(toggle.bind(&"reputation"))
	gameMenu.Chosen.connect(closePopover)
	universityMenu.BuildingChosen.connect(showBuilding)
	universityMenu.ReputationChosen.connect(openPopover.bind(&"reputation"))
	universityMenu.HousingChosen.connect(openPopover.bind(PopoverHousing))
	universityMenu.FinancesChosen.connect(openPopover.bind(PopoverMoney))
	studentsDropdown.ReputationJumped.connect(openPopover.bind(&"reputation"))
	studentsDropdown.HousingJumped.connect(openPopover.bind(PopoverHousing))
	reputationDropdown.HousingJumped.connect(openPopover.bind(PopoverHousing))
	housingDropdown.AdmissionsJumped.connect(func() -> void: showPane(PaneAdmissions))


func setup(gameState: GameState, gameCamera: GameCamera, buildController: BuildController, buildingDB: BuildingInfoDB) -> void:
	state = gameState
	camera = gameCamera
	controller = buildController
	campusMarkers.setup(state.university, camera)
	campusMarkers.ProblemWanted.connect(openProblem)
	campusMarkers.BuildingWanted.connect(showBuilding)
	topBar.state = state
	universityMenu.university = state.university
	studentsDropdown.setUniversity(state.university)
	reputationDropdown.university = state.university
	housingDropdown.setUniversity(state.university)
	moneyDropdown.setState(state)
	sidePanel.setUniversity(state.university)
	alerts.setup(state)
	alerts.PlaceWanted.connect(_openPlace)
	controller.SelectionChanged.connect(sidePanel.showBuilding)
	sidePanel.CloseRequested.connect(func() -> void: controller.select(null))
	sidePanel.PopoverWanted.connect(openPopover)
	sidePanel.BuildingWanted.connect(showBuilding)
	sidePanel.BuildWanted.connect(openBuildPanel)
	controller.NothingToCancel.connect(openPopover.bind(&"gamemenu"))
	state.university.SemesterStarted.connect(showReport)
	semesterPopup.Continued.connect(_onContinued)
	semesterPopup.HousingWanted.connect(_onHousingWanted)
	buildPanel.university = state.university
	buildPanel.populate(buildingDB)
	buildPanel.showAffordable(state.university.campus)
	state.university.finances.MoneyChanged.connect(func() -> void: buildPanel.showAffordable(state.university.campus))
	buildPanel.BuildingChosen.connect(_armPlace)
	actionBar.BuildPressed.connect(toggle.bind(PopoverBuild))
	actionBar.DemolishPressed.connect(_toggleDemolish)
	controller.ToolChanged.connect(_onToolChanged)


# Keeps the alerts to the left of the side panel while it's open; the anchors
# are both pinned to the right edge, so left and right shift together.
func _process(_dt: float) -> void:
	var shift: float = -(AlertsMargin + (sidePanel.size.x if (sidePanel.visible) else 0.0))
	alerts.offset_right = shift
	alerts.offset_left = shift


func popoverOpen() -> StringName:
	return _open


## Whether a name is one of the popovers, for the console.
func hasPopover(which: StringName) -> bool:
	return _popovers.has(which)


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
	actionBar.showBuildOpen(_open == PopoverBuild)


## Closes whichever popover is open. Answers whether one was.
func closePopover() -> bool:
	if (_open == None):
		return false
	_popovers[_open].visible = false
	topBar.setOpen(_open, false)
	_open = None
	actionBar.showBuildOpen(_open == PopoverBuild)
	return true


func showBuilding(building: Building) -> void:
	closePopover()
	controller.select(building)
	camera.setTarget(building.pos)


## Shows the pane a name stands for, by selecting its first building and
## moving the camera to it; does nothing when there is no such building.
## Answers whether there was one. For the console and the keys.
func showPane(which: StringName) -> bool:
	var found: Building = _firstFor(which)
	if (found == null):
		return false
	showBuilding(found)
	return true


func _firstFor(which: StringName) -> Building:
	if (which == PaneConstruction):
		for building: Building in state.university.campus.buildings:
			if (building.underConstruction):
				return building
	elif (which == PaneAdmissions):
		return _firstOpen(BuildingInfo.Role.Admissions)
	elif (which == PaneAcademic):
		return _firstOpen(BuildingInfo.Role.Academic)
	elif (which == PaneDorm):
		return _firstOpen(BuildingInfo.Role.Housing)
	elif (which == PaneDining):
		return _firstOpen(BuildingInfo.Role.Dining)
	return null


func _firstOpen(role: BuildingInfo.Role) -> Building:
	var found: Array[Building] = state.university.campus.openWithRole(role)
	return found[0] if (not found.is_empty()) else null


## Where a problem is dealt with: its dropdown, or its building's pane.
func openProblem(kind: Problem.Kind) -> void:
	match kind:
		Problem.Kind.HousingOverflow:
			openPopover(PopoverHousing)
		Problem.Kind.DiningCrowded, Problem.Kind.DiningUnfed:
			if (not showPane(PaneDining)):
				openPopover(PopoverHousing)
		Problem.Kind.CreditMaxed:
			openPopover(PopoverMoney)


func _openPlace(entry: AlertEntry) -> void:
	match entry.source:
		AlertEntry.Source.Problem:
			openProblem(entry.problem.kind)
		AlertEntry.Source.AutoBorrowed:
			openPopover(PopoverMoney)
		AlertEntry.Source.Opened:
			if (state.university.campus.buildings.has(entry.building)):
				showBuilding(entry.building)


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
	openPopover(PopoverHousing)


## Opens the build panel on one category, as the panes' "add a building" jumps do.
func openBuildPanel(category: String) -> void:
	openPopover(PopoverBuild)
	buildPanel.showCategory(category)


# Choosing a card arms it and puts the panel away, so the ground is clear to place on.
func _armPlace(info: BuildingInfo) -> void:
	controller.armPlace(info)
	closePopover()


# Demolish, the button or X, arms the destroy tool, or puts it away when armed.
func _toggleDemolish() -> void:
	if (controller.activeTool == BuildController.Tool.Destroy):
		controller.cancel()
	else:
		controller.armDestroy()


func _onToolChanged() -> void:
	buildPanel.showTool(controller.activeTool, controller.placeInfo)
	actionBar.showTool(controller.activeTool)


func _unhandled_input(event: InputEvent) -> void:
	if (semesterPopup.visible):
		# The popup is modal: Continue, Esc and "Look at housing" are the ways
		# out, and Space, B and X do nothing while it is up.
		if (event.is_action_pressed(&"ExitGame")):
			semesterPopup.dismiss()
			get_viewport().set_input_as_handled()
		elif (event.is_action_pressed(&"TogglePause") or event.is_action_pressed(&"ToggleBuild") or event.is_action_pressed(&"Demolish")
			or event.is_action_pressed(&"UniversityMenu") or event.is_action_pressed(&"AdmissionsPane") or event.is_action_pressed(&"MoneyPanel")):
			get_viewport().set_input_as_handled()
		return
	if (event.is_action_pressed(&"ExitGame") and closePopover()):
		get_viewport().set_input_as_handled()
		return
	if (event.is_action_pressed(&"ToggleBuild")):
		toggle(PopoverBuild)
		get_viewport().set_input_as_handled()
		return
	if (event.is_action_pressed(&"Demolish")):
		_toggleDemolish()
		get_viewport().set_input_as_handled()
		return
	if (event.is_action_pressed(&"UniversityMenu")):
		toggle(PopoverUniversity)
		get_viewport().set_input_as_handled()
		return
	if (event.is_action_pressed(&"AdmissionsPane")):
		showPane(PaneAdmissions)
		get_viewport().set_input_as_handled()
		return
	if (event.is_action_pressed(&"MoneyPanel")):
		toggle(PopoverMoney)
		get_viewport().set_input_as_handled()
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		# The world gets the click too: closing a popover never swallows it.
		closePopover()
