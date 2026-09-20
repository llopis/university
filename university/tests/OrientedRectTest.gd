extends GdUnitTestSuite
## Rotated-rectangle maths on the ground plane (x = world X, y = world Z).
## Fixtures are arbitrary sizes; assertions are geometric relationships.

const Epsilon: float = 0.0001
const Long: float = 10.0
const Short: float = 2.0
const BoxHeight: float = 10.0
const QuarterTurn: float = PI / 2.0
const EighthTurn: float = PI / 4.0
# Metres out along the bar's long axis: inside it, well clear of the short one.
const Reach: float = 3.0


func _bar(center: Vector2, angle: float) -> OrientedRect:
	return OrientedRect.new(center, Vector2(Long, Short), angle)


func test_axis_aligned_rects_overlap() -> void:
	assert_bool(_bar(Vector2.ZERO, 0.0).overlaps(_bar(Vector2(Long / 2.0, 0.0), 0.0))).is_true()


func test_separated_rects_do_not_overlap() -> void:
	assert_bool(_bar(Vector2.ZERO, 0.0).overlaps(_bar(Vector2(Long * 2.0, 0.0), 0.0))).is_false()


func test_rects_touching_along_an_edge_do_not_overlap() -> void:
	assert_bool(_bar(Vector2.ZERO, 0.0).overlaps(_bar(Vector2(0.0, Short), 0.0))).is_false()


func test_overlap_is_symmetric() -> void:
	var a: OrientedRect = _bar(Vector2.ZERO, EighthTurn)
	var b: OrientedRect = _bar(Vector2(3.0, 1.0), 0.0)
	assert_bool(a.overlaps(b)).is_equal(b.overlaps(a))


func test_rotated_corner_poking_into_a_rect_overlaps() -> void:
	# A diamond whose tip reaches into the bar from above.
	var diamond: OrientedRect = OrientedRect.new(Vector2(0.0, 3.0), Vector2(4.0, 4.0), EighthTurn)
	assert_bool(_bar(Vector2.ZERO, 0.0).overlaps(diamond)).is_true()


func test_rects_with_overlapping_bounding_boxes_can_still_be_separate() -> void:
	# A thin diagonal bar; the square sits inside the bar's bounding box but
	# clear of the bar itself. Only a separating-axis test gets this right.
	var diagonal: OrientedRect = _bar(Vector2.ZERO, EighthTurn)
	var square: OrientedRect = OrientedRect.new(Vector2(3.0, -3.0), Vector2(2.0, 2.0), 0.0)
	assert_bool(diagonal.overlaps(square)).is_false()


func test_contains_follows_the_rotation() -> void:
	var upright: OrientedRect = _bar(Vector2.ZERO, QuarterTurn)
	assert_bool(upright.contains(Vector2(0.0, 4.0))).is_true()
	assert_bool(upright.contains(Vector2(4.0, 0.0))).is_false()


func test_contains_pins_the_sign_of_the_angle() -> void:
	# An eighth turn is not symmetric under a -> -a, so this is the one shape
	# that catches a flipped sign: the bar's long axis must point at +X+Z.
	var diagonal: OrientedRect = _bar(Vector2.ZERO, EighthTurn)
	var along: Vector2 = Vector2(1.0, 1.0).normalized() * Reach
	assert_bool(diagonal.contains(along)).is_true()
	assert_bool(diagonal.contains(Vector2(along.x, -along.y))).is_false()


func test_corners_are_at_half_extents_from_the_center() -> void:
	var rect: OrientedRect = _bar(Vector2(5.0, 5.0), EighthTurn)
	var halfDiagonal: float = Vector2(Long, Short).length() / 2.0
	for corner: Vector2 in rect.corners():
		assert_float(corner.distance_to(rect.center)).is_equal_approx(halfDiagonal, Epsilon)


func test_within_bounds() -> void:
	var bounds: Rect2 = Rect2(-10.0, -10.0, 20.0, 20.0)
	assert_bool(_bar(Vector2.ZERO, 0.0).within(bounds)).is_true()
	assert_bool(_bar(Vector2(8.0, 0.0), 0.0).within(bounds)).is_false()
	# Fits lying down, pokes out once turned upright near the top edge.
	assert_bool(_bar(Vector2(0.0, 8.0), 0.0).within(bounds)).is_true()
	assert_bool(_bar(Vector2(0.0, 8.0), QuarterTurn).within(bounds)).is_false()


func test_ray_from_above_hits_the_roof() -> void:
	var rect: OrientedRect = _bar(Vector2.ZERO, 0.0)
	var hit: float = rect.rayHit(Vector3(0.0, 50.0, 0.0), Vector3.DOWN, BoxHeight)
	assert_float(hit).is_equal_approx(50.0 - BoxHeight, Epsilon)


func test_ray_from_the_side_hits_the_wall() -> void:
	var rect: OrientedRect = _bar(Vector2.ZERO, 0.0)
	var hit: float = rect.rayHit(Vector3(-50.0, 5.0, 0.0), Vector3.RIGHT, BoxHeight)
	assert_float(hit).is_equal_approx(50.0 - Long / 2.0, Epsilon)


func test_ray_hit_follows_the_rotation() -> void:
	var upright: OrientedRect = _bar(Vector2.ZERO, QuarterTurn)
	var hit: float = upright.rayHit(Vector3(-50.0, 5.0, 0.0), Vector3.RIGHT, BoxHeight)
	assert_float(hit).is_equal_approx(50.0 - Short / 2.0, Epsilon)


func test_ray_that_passes_beside_or_points_away_misses() -> void:
	var rect: OrientedRect = _bar(Vector2.ZERO, 0.0)
	assert_float(rect.rayHit(Vector3(-50.0, 5.0, 20.0), Vector3.RIGHT, BoxHeight)).is_equal(OrientedRect.NoHit)
	assert_float(rect.rayHit(Vector3(-50.0, 5.0, 0.0), Vector3.LEFT, BoxHeight)).is_equal(OrientedRect.NoHit)
	assert_float(rect.rayHit(Vector3(0.0, 50.0, 0.0), Vector3.UP, BoxHeight)).is_equal(OrientedRect.NoHit)
