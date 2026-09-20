class_name OrientedRect
## A rectangle on the ground plane (x = world X, y = world Z) turned by
## `angle` radians: its own x axis points along (cos angle, sin angle). The one
## place rotated-rectangle maths lives — overlap, containment and ray picking.

# Slack for comparisons, in metres: rects that only touch do not overlap.
const Epsilon: float = 0.0001
const NoHit: float = -1.0

var center: Vector2
# Full extents along the rect's own x and y axes.
var size: Vector2
var angle: float


func _init(rectCenter: Vector2, rectSize: Vector2, rectAngle: float) -> void:
	center = rectCenter
	size = rectSize
	angle = rectAngle


func axisX() -> Vector2:
	return Vector2(cos(angle), sin(angle))


func axisY() -> Vector2:
	return Vector2(-sin(angle), cos(angle))


## The point in the rect's own frame: origin at the centre, axes along its sides.
func toLocal(point: Vector2) -> Vector2:
	var offset: Vector2 = point - center
	return Vector2(offset.dot(axisX()), offset.dot(axisY()))


func corners() -> PackedVector2Array:
	var halfX: Vector2 = axisX() * size.x / 2.0
	var halfY: Vector2 = axisY() * size.y / 2.0
	return PackedVector2Array([
		center - halfX - halfY,
		center + halfX - halfY,
		center + halfX + halfY,
		center - halfX + halfY,
	])


func contains(point: Vector2) -> bool:
	var local: Vector2 = toLocal(point)
	return absf(local.x) <= size.x / 2.0 + Epsilon and absf(local.y) <= size.y / 2.0 + Epsilon


## Separating-axis test over both rects' side directions.
func overlaps(other: OrientedRect) -> bool:
	var between: Vector2 = other.center - center
	for axis: Vector2 in [axisX(), axisY(), other.axisX(), other.axisY()]:
		var gap: float = absf(between.dot(axis)) - _reach(axis) - other._reach(axis)
		if (gap >= -Epsilon):
			return false
	return true


# Half the rect's extent along a unit axis.
func _reach(axis: Vector2) -> float:
	return (absf(axisX().dot(axis)) * size.x + absf(axisY().dot(axis)) * size.y) / 2.0


func within(bounds: Rect2) -> bool:
	for corner: Vector2 in corners():
		if (corner.x < bounds.position.x - Epsilon or corner.x > bounds.end.x + Epsilon):
			return false
		if (corner.y < bounds.position.y - Epsilon or corner.y > bounds.end.y + Epsilon):
			return false
	return true


## Distance along a ray (unit `dir`) to the box standing on the ground with
## this footprint and the given height, or NoHit. The ray is turned into the
## rect's frame, where the box is axis-aligned, and clipped slab by slab.
func rayHit(origin: Vector3, dir: Vector3, height: float) -> float:
	var localOrigin: Vector2 = toLocal(Vector2(origin.x, origin.z))
	var flatDir: Vector2 = Vector2(dir.x, dir.z)
	var rayStart: Vector3 = Vector3(localOrigin.x, origin.y, localOrigin.y)
	var rayStep: Vector3 = Vector3(flatDir.dot(axisX()), dir.y, flatDir.dot(axisY()))
	var low: Vector3 = Vector3(-size.x / 2.0, 0.0, -size.y / 2.0)
	var high: Vector3 = Vector3(size.x / 2.0, height, size.y / 2.0)
	var near: float = 0.0
	var far: float = INF
	for i: int in range(3):
		var start: float = rayStart[i]
		var step: float = rayStep[i]
		var slabLow: float = low[i]
		var slabHigh: float = high[i]
		if (absf(step) < Epsilon):
			if (start < slabLow or start > slabHigh):
				return NoHit
			continue
		var enter: float = (slabLow - start) / step
		var leave: float = (slabHigh - start) / step
		near = maxf(near, minf(enter, leave))
		far = minf(far, maxf(enter, leave))
	if (near > far):
		return NoHit
	return near
