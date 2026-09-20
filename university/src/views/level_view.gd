class_name LevelView
extends Node2D

@onready var gameRoot: Node2D = %GameRoot
@onready var playerView: PlayerView = %PlayerView
@onready var statusBar: StatusBar = %StatusBar



var gameState: GameState


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	gameState = Global.gameState
	gameState.level.EnemyAdded.connect(_onEnemyAdded)
	gameState.level.createNewLevel()
	
	statusBar.gameState = gameState
	
	playerView.player = gameState.level.player


func _process(dt: float) -> void:
	gameState.update(dt)


func _onEnemyAdded(enemy: Enemy) -> void:
	var enemyView: EnemyView = EnemyView.create(enemy)
	gameRoot.add_child(enemyView)


func _unhandled_input(event: InputEvent):
	if (event.is_action_pressed("ExitGame")):
		get_tree().quit()
