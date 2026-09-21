extends GdUnitTestSuite
## The one state-angle-to-node-rotation conversion. Built off the scene tree:
## the box's own axes must line up with the footprint's, sign included.

const Epsilon: float = 0.0001
const Diameter: float = 20.0
# Not a quarter turn: a flipped sign has to show up as a different basis.
const Angle: float = PI / 6.0
const Position: Vector2 = Vector2(30.0, -40.0)


func _info() -> BuildingInfo:
	return BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter})


func _view(building: Building) -> BuildingView:
	return auto_free(BuildingView.create(building)) as BuildingView


func test_the_box_axes_follow_the_footprint_axes() -> void:
	var building: Building = Building.new(_info(), Position, Angle)
	var view: BuildingView = _view(building)
	var rect: OrientedRect = building.rect()
	var basisX: Vector2 = Vector2(view.transform.basis.x.x, view.transform.basis.x.z)
	var basisZ: Vector2 = Vector2(view.transform.basis.z.x, view.transform.basis.z.z)
	assert_vector(basisX).is_equal_approx(rect.axisX(), Vector2(Epsilon, Epsilon))
	assert_vector(basisZ).is_equal_approx(rect.axisY(), Vector2(Epsilon, Epsilon))


func test_the_box_is_the_footprint_extruded_to_the_building_height() -> void:
	var building: Building = Building.new(_info(), Position, Angle)
	var view: BuildingView = _view(building)
	var rect: OrientedRect = building.rect()
	var box: BoxMesh = view.mesh as BoxMesh
	assert_vector(box.size).is_equal_approx(
		Vector3(rect.size.x, Building.Height, rect.size.y), Vector3(Epsilon, Epsilon, Epsilon))


func test_the_box_stands_on_the_ground_over_the_footprint_centre() -> void:
	var building: Building = Building.new(_info(), Position, Angle)
	var view: BuildingView = _view(building)
	assert_vector(view.position).is_equal_approx(
		Vector3(Position.x, Building.Height / 2.0, Position.y), Vector3(Epsilon, Epsilon, Epsilon))


func _albedo(view: BuildingView) -> Color:
	return (view.material_override as StandardMaterial3D).albedo_color


func test_a_building_under_construction_draws_translucent_until_it_opens() -> void:
	var building: Building = Building.new(_info(), Vector2.ZERO, 0.0)
	var view: BuildingView = _view(building)
	assert_float(_albedo(view).a).is_less(1.0)
	view.setUnderConstruction(false)
	assert_float(_albedo(view).a).is_equal(1.0)


func test_a_highlight_keeps_the_construction_look() -> void:
	var building: Building = Building.new(_info(), Vector2.ZERO, 0.0)
	var view: BuildingView = _view(building)
	view.setHighlight(BuildingView.Highlight.Selected)
	assert_float(_albedo(view).a).is_less(1.0)
	assert_float(_albedo(view).r).is_equal(BuildingView.SelectedColor.r)
