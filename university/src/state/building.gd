class_name Building
## A building standing on the campus. Position is on the ground plane
## (x = world X, y = world Z), angle in radians (see OrientedRect).

# The footprint's short side as a fraction of BuildingInfo.diameter, which is
# its long side. A placeholder until building types carry their own shape.
const DepthRatio: float = 0.6
# Metres. State rather than view because picking tests the box, not the footprint.
const Height: float = 10.0

var info: BuildingInfo
var pos: Vector2
var angle: float
# True from placement until the campus opens it at the start of a semester.
var underConstruction: bool = true
# The month index at which it opens. Stamped by the campus on placement.
var opensAtMonth: int = 0


func _init(buildingInfo: BuildingInfo, at: Vector2, facing: float) -> void:
	info = buildingInfo
	pos = at
	angle = facing


func rect() -> OrientedRect:
	return Building.rectFor(info, pos, angle)


## The footprint a building of this type would have there: the one derivation
## shared by placed buildings, the placement check and the ghost.
static func rectFor(buildingInfo: BuildingInfo, at: Vector2, facing: float) -> OrientedRect:
	var size: Vector2 = Vector2(buildingInfo.diameter, buildingInfo.diameter * DepthRatio)
	return OrientedRect.new(at, size, facing)


# Keys toDict writes; fromDict refuses a dictionary missing any of them.
const SavedKeys: Array[String] = ["type", "pos", "angle", "underConstruction", "opensAtMonth"]


## The type is saved by id; the campus looks it up when loading.
func toDict() -> Dictionary:
	return {
		"type": info.id,
		"pos": [pos.x, pos.y],
		"angle": angle,
		"underConstruction": underConstruction,
		"opensAtMonth": opensAtMonth,
	}


## A saved building standing again, as the type it was looked up to be
## (`type` is read by `Campus.fromDict`, which looks it up before calling
## here). Null when data is missing a key.
static func fromDict(data: Dictionary, buildingInfo: BuildingInfo) -> Building:
	if (not Variants.hasKeys(data, SavedKeys, "Building")):
		return null
	var saved: Array = data["pos"] as Array
	var at: Vector2 = Vector2(Variants.toFloat(saved[0]), Variants.toFloat(saved[1]))
	var building: Building = Building.new(buildingInfo, at, Variants.toFloat(data["angle"]))
	building.underConstruction = Variants.toBool(data["underConstruction"])
	building.opensAtMonth = Variants.toInt(data["opensAtMonth"])
	return building
