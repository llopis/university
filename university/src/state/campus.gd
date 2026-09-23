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
	var refunded: int = refundFor(building)
	if (refunded > 0):
		finances.refund(refunded)
	BuildingRemoved.emit(building)


## A new month began: every building due by now opens. The due ones are
## collected before any is announced, so a listener that destroys the building
## it hears about cannot cut the pass short. Answers the buildings it opened,
## in the order announced.
func startMonth(newMonth: int) -> Array[Building]:
	month = newMonth
	var due: Array[Building] = []
	for building: Building in buildings:
		if (building.underConstruction and building.opensAtMonth <= month):
			due.append(building)
	var opened: Array[Building] = []
	for building: Building in due:
		# A listener may have destroyed it while an earlier one was announced.
		if (not buildings.has(building)):
			continue
		building.underConstruction = false
		opened.append(building)
		BuildingOpened.emit(building)
	return opened


## The month's upkeep in whole dollars: every open building's. One still under
## construction costs nothing yet.
func upkeep() -> int:
	return _totalBy(month, func(info: BuildingInfo) -> int: return info.upkeep)


## Academic seats in open buildings.
func seats() -> int:
	return seatsBy(month)


## Beds in open buildings.
func beds() -> int:
	return bedsBy(month)


## The diners every open dining hall is meant for, together.
func meals() -> int:
	return mealsBy(month)


## Whether an open building grants the price and minimum-grade levers.
func hasOpenAdmissionsOffice() -> bool:
	return hasAdmissionsOfficeBy(month)


## Seats in buildings open by that month: open now, or opening at or before it.
## Projections count what a coming semester start will open.
func seatsBy(byMonth: int) -> int:
	return _totalBy(byMonth, func(info: BuildingInfo) -> int: return info.seats)


func bedsBy(byMonth: int) -> int:
	return _totalBy(byMonth, func(info: BuildingInfo) -> int: return info.beds)


func mealsBy(byMonth: int) -> int:
	return _totalBy(byMonth, func(info: BuildingInfo) -> int: return info.meals)


func hasAdmissionsOfficeBy(byMonth: int) -> bool:
	for building: Building in buildings:
		if (_isOpenBy(building, byMonth) and building.info.admissionsOffice):
			return true
	return false


## The buildings open now, in placement order.
func openBuildings() -> Array[Building]:
	var open: Array[Building] = []
	for building: Building in buildings:
		if (not building.underConstruction):
			open.append(building)
	return open


## The open buildings of one role, in placement order.
func openWithRole(role: BuildingInfo.Role) -> Array[Building]:
	var found: Array[Building] = []
	for building: Building in openBuildings():
		if (building.info.role() == role):
			found.append(building)
	return found


## What the open buildings hold of one role: seats, beds or meals.
func capacityFor(role: BuildingInfo.Role) -> int:
	match role:
		BuildingInfo.Role.Academic:
			return seats()
		BuildingInfo.Role.Housing:
			return beds()
		BuildingInfo.Role.Dining:
			return meals()
	return 0


## What destroying a building gives back: its full cost while it is still under
## construction, nothing once it has opened. The one rule destroy and the
## Demolish button both read.
func refundFor(building: Building) -> int:
	return building.info.cost if (building.underConstruction) else 0


# Open now, or due to open by that month. At the campus's own month this is
# exactly "open": a building placed this month opens at a later one.
static func _isOpenBy(building: Building, byMonth: int) -> bool:
	return not building.underConstruction or building.opensAtMonth <= byMonth


# The one sum over buildings open by a month: amount answers what one type contributes.
func _totalBy(byMonth: int, amount: Callable) -> int:
	var total: int = 0
	for building: Building in buildings:
		if (_isOpenBy(building, byMonth)):
			total += Variants.toInt(amount.call(building.info))
	return total


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
