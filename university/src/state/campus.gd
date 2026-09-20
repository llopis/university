class_name Campus
## The buildable world: a square of ground and the buildings on it. Views call
## the command methods (place, destroy) and listen to the signals; nothing here
## reads input or knows a view exists.

signal BuildingAdded(building: Building)
signal BuildingRemoved(building: Building)

# Side of the square campus, in metres, centred on the origin.
const Size: float = 1000.0

var buildings: Array[Building]


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


## The new building, or null when the spot is not free.
func place(info: BuildingInfo, pos: Vector2, angle: float) -> Building:
	if (not canPlace(info, pos, angle)):
		return null
	var building: Building = Building.new(info, pos, angle)
	buildings.append(building)
	BuildingAdded.emit(building)
	return building


func destroy(building: Building) -> void:
	if (not buildings.has(building)):
		return
	buildings.erase(building)
	BuildingRemoved.emit(building)


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
