class_name CampusView
extends Node3D
## Root of the game scene: hosts the lights, the ground, the camera and the UI,
## and drives the state clock. Lighting and layout are authored in the scene.

@onready var camera: GameCamera = %Camera
@onready var statusBar: StatusBar = %StatusBar
@onready var buildingsRoot: Node3D = %Buildings

var gameState: GameState

var _views: Dictionary[Building, BuildingView]


func _ready() -> void:
	gameState = Global.gameState
	statusBar.gameState = gameState
	gameState.campus.BuildingAdded.connect(_onBuildingAdded)
	gameState.campus.BuildingRemoved.connect(_onBuildingRemoved)


func _process(dt: float) -> void:
	gameState.update(dt)


func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("ExitGame")):
		get_tree().quit()


func viewFor(building: Building) -> BuildingView:
	return _views.get(building) as BuildingView


func _onBuildingAdded(building: Building) -> void:
	var view: BuildingView = BuildingView.create(building)
	_views[building] = view
	buildingsRoot.add_child(view)


func _onBuildingRemoved(building: Building) -> void:
	var view: BuildingView = viewFor(building)
	_views.erase(building)
	view.queue_free()
