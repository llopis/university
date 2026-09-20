class_name CampusView
extends Node3D
## Root of the game scene: hosts the lights, the ground, the camera and the UI,
## and drives the state clock. Lighting and layout are authored in the scene.

@onready var camera: GameCamera = %Camera
@onready var statusBar: StatusBar = %StatusBar

var gameState: GameState


func _ready() -> void:
	gameState = Global.gameState
	statusBar.gameState = gameState


func _process(dt: float) -> void:
	gameState.update(dt)


func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("ExitGame")):
		get_tree().quit()
