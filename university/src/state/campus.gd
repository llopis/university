class_name Campus
## The buildable world: a square of ground and the buildings on it. Building
## spends from, and a refund goes back to, the university's Finances. Views call
## the command methods (place, destroy) and listen to the signals; nothing here
## reads input or knows a view exists.

signal BuildingAdded(building: Building)
signal BuildingRemoved(building: Building)
## A building finished construction: a semester began.
signal BuildingOpened(building: Building)

# Side of the square campus, in metres, centred on the origin.
const Size: float = 1000.0
# Reported when a save names a building type the building data no longer has.
const UnknownTypeError: String = "Campus: saved building type '%s' is not in the building data; leaving it out."
# Keys toDict writes; fromDict refuses a dictionary missing any of them.
const SavedKeys: Array[String] = ["month", "buildings"]

var buildings: Array[Building]
# The university's money, shared: what building spends from.
var finances: Finances
# Months since the game began (see GameCalendar). Advanced by startMonth.
var month: int = 0


func _init(fundedBy: Finances) -> void:
	finances = fundedBy


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


func canAfford(info: BuildingInfo) -> bool:
	return finances.canAfford(info.cost)


## Whether a building of this type can go there right now: the spot is free
## and the cash covers it. Cash never goes negative.
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
	finances.spend(info.cost)
	BuildingAdded.emit(building)
	return building


## Removes a building. One still under construction is refunded in full; an
## open one gives nothing back.
func destroy(building: Building) -> void:
	if (not buildings.has(building)):
		return
	buildings.erase(building)
	if (building.underConstruction):
		finances.refund(building.info.cost)
	BuildingRemoved.emit(building)


## The month's upkeep in whole dollars: every open building's. One still under
## construction costs nothing yet.
func upkeep() -> int:
	var total: int = 0
	for building: Building in buildings:
		if (not building.underConstruction):
			total += building.info.upkeep
	return total


## A new month began: every building due by now opens. The due ones are
## collected before any is announced, so a listener that destroys the building
## it hears about cannot cut the pass short.
func startMonth(newMonth: int) -> void:
	month = newMonth
	var due: Array[Building] = []
	for building: Building in buildings:
		if (building.underConstruction and building.opensAtMonth <= month):
			due.append(building)
	for building: Building in due:
		# A listener may have destroyed it while an earlier one was announced.
		if (not buildings.has(building)):
			continue
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


func toDict() -> Dictionary:
	var saved: Array[Dictionary] = []
	for building: Building in buildings:
		saved.append(building.toDict())
	return {"month": month, "buildings": saved}


## A saved campus, spending from the finances it is given (the loaded ones), and
## rebuilt without announcing any building: nothing is listening yet, and the
## view makes what it needs from `buildings` when it starts. A building whose
## type is gone from the data is reported and left out; a save missing a key,
## at the campus level or a building's, is refused: null for the whole campus.
static func fromDict(data: Dictionary, buildingDB: BuildingInfoDB, fundedBy: Finances) -> Campus:
	if (not Variants.hasKeys(data, SavedKeys, "Campus")):
		return null
	var campus: Campus = Campus.new(fundedBy)
	campus.month = Variants.toInt(data["month"])
	for saved: Variant in data["buildings"] as Array:
		var entry: Dictionary = saved as Dictionary
		# Checked before reading "type", which Building.fromDict never reads
		# itself (it is given buildingInfo already looked up).
		if (not Variants.hasKeys(entry, Building.SavedKeys, "Campus building")):
			return null
		var typeId: String = str(entry["type"])
		var buildingInfo: BuildingInfo = buildingDB.info(typeId)
		if (buildingInfo == null):
			push_error(UnknownTypeError % typeId)
			continue
		var building: Building = Building.fromDict(entry, buildingInfo)
		if (building == null):
			return null
		campus.buildings.append(building)
	return campus
