class_name Campus
## The buildable world: a square of ground, the buildings on it, and the
## money spent building them. Views call the command methods (place, destroy)
## and listen to the signals; nothing here reads input or knows a view exists.

signal BuildingAdded(building: Building)
signal BuildingRemoved(building: Building)
signal MoneyChanged(money: int)
## A building finished construction: a semester began.
signal BuildingOpened(building: Building)

# Side of the square campus, in metres, centred on the origin.
const Size: float = 1000.0
# Whole dollars.
const StartingMoney: int = 10000000

var buildings: Array[Building]
var money: int = StartingMoney
# Months since the game began (see GameCalendar). Advanced by startMonth.
var month: int = 0


static func bounds() -> Rect2:
	return Rect2(-Size / 2.0, -Size / 2.0, Size, Size)


func canPlace(info: BuildingInfo, pos: Vector2, angle: float) -> bool:
	var rect: OrientedRect = Building.rectFor(info, pos, angle)
	if (not rect.within(Campus.bounds())):
		return false
	for building: Building in buildings:
		if (rect.overlaps(building.rect())):
			return false
	return true


## The one place the balance is written, so every change is announced.
func setMoney(amount: int) -> void:
	money = amount
	MoneyChanged.emit(money)


func canAfford(info: BuildingInfo) -> bool:
	return info.cost <= money


## Whether a building of this type can go there right now: the spot is free
## and it can be paid for. Money never goes negative.
func canBuild(info: BuildingInfo, pos: Vector2, angle: float) -> bool:
	return canAfford(info) and canPlace(info, pos, angle)


## The new building, or null when it cannot be built there. It is paid for now
## and stays under construction until the next semester begins.
func place(info: BuildingInfo, pos: Vector2, angle: float) -> Building:
	if (not canBuild(info, pos, angle)):
		return null
	var building: Building = Building.new(info, pos, angle)
	building.opensAtMonth = GameCalendar.nextSemesterStart(month)
	buildings.append(building)
	setMoney(money - info.cost)
	BuildingAdded.emit(building)
	return building


## Removes a building. One still under construction is refunded in full; an
## open one gives nothing back.
func destroy(building: Building) -> void:
	if (not buildings.has(building)):
		return
	buildings.erase(building)
	if (building.underConstruction):
		setMoney(money + building.info.cost)
	BuildingRemoved.emit(building)


## A new month began: every building due by now opens.
func startMonth(newMonth: int) -> void:
	month = newMonth
	for building: Building in buildings:
		if (building.underConstruction and building.opensAtMonth <= month):
			building.underConstruction = false
			BuildingOpened.emit(building)


## The first building a ray (unit `dir`) reaches, or null.
func pick(origin: Vector3, dir: Vector3) -> Building:
	var nearest: Building = null
	var nearestHit: float = INF
	for building: Building in buildings:
		var hit: float = building.rect().rayHit(origin, dir, Building.Height)
		if (hit != OrientedRect.NoHit and hit < nearestHit):
			nearest = building
			nearestHit = hit
	return nearest


func tick(_dt: float) -> void:
	pass


func update(_dt: float) -> void:
	pass
