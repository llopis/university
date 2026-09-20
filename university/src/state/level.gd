class_name Level

signal EnemyAdded()


var player: Player
var enemies: Array[Enemy]
var timeUntilNewEnemy: float


const WorldWidth: float = 1920
const WorldHeight: float = 1080
const TimeBetweenEnemies: float = 4


func _init() -> void:
	player = Player.new()
	player.pos = Vector2(WorldWidth/2,WorldHeight/2)
	timeUntilNewEnemy = TimeBetweenEnemies


func createNewLevel() -> void:
	for i:int in range(0,5):
		_addEnemy()


func tick(dt: float) -> void:
	player.tick(dt)
	for enemy: Enemy in enemies:
		enemy.tick(dt)



func update(dt: float) -> void:
	timeUntilNewEnemy -= dt
	if (timeUntilNewEnemy <= 0):
		_addEnemy()
		timeUntilNewEnemy = TimeBetweenEnemies
	


func _addEnemy() -> void:
	var enemy: Enemy = Enemy.new()
	enemy.pos = Vector2(randf_range(0,WorldWidth-50), randf_range(0,WorldHeight-50)) 
	enemies.push_back(enemy)
	EnemyAdded.emit(enemy)
