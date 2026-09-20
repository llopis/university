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
