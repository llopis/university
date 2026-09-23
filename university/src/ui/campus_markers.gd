class_name CampusMarkers
extends Control
## Labels over the campus, where things need looking at: housing overflow over
## the dorms, dining trouble over the dining halls, and every building still
## going up. Re-placed every frame from the camera, so they follow panning and
## turning. Clicking one asks for its place.

signal ProblemWanted(kind: Problem.Kind)
signal BuildingWanted(building: Building)

const MarkerScene: PackedScene = preload("res://src/ui/campus_marker.tscn")

const HousingOverflowText: String = "%s off campus"
const HousingOverflowSmallFormat: String = "%s · above %s"
const DiningLoadFormat: String = "Dining at %s"
const DiningCrowdedSmall: String = "crowded"
const DiningUnfedSmall: String = "can't eat"
const OpensFormat: String = "Opens %s"

const AccentWarn: String = "Warn"
const AccentBad: String = "Bad"
const AccentInfo: String = "Info"

var university: University
var camera: GameCamera
var _pool: Array[CampusMarker]


func setup(shown: University, gameCamera: GameCamera) -> void:
	university = shown
	camera = gameCamera


func _process(_dt: float) -> void:
	if (university == null or camera == null):
		return
	var used: int = 0
	used = _placeHousing(used)
	used = _placeDining(used)
	used = _placeConstruction(used)
	for i: int in range(used, _pool.size()):
		_pool[i].visible = false


## A marker over the dorms' centroid while students are without on-campus
## housing past UniversityRules.OverflowThreshold.
func _placeHousing(index: int) -> int:
	if (not university.hasProblem(Problem.Kind.HousingOverflow)):
		return index
	var point: Vector2 = Campus.centroid(university.campus.openWithRole(BuildingInfo.Role.Housing))
	var text: String = HousingOverflowText % NumberFormat.count(university.offCampus())
	var small: String = HousingOverflowSmallFormat % [NumberFormat.percent(university.offCampusShare()), NumberFormat.percent(UniversityRules.OverflowThreshold)]
	var marker: CampusMarker = _place(index, point, text, small, AccentBad)
	marker.building = null
	marker.problemKind = Problem.Kind.HousingOverflow
	return index + 1


## A marker over the dining halls' centroid while dining is crowded or
## someone can't eat; none while there is nothing to show or no dining hall.
func _placeDining(index: int) -> int:
	var diningHalls: Array[Building] = university.campus.openWithRole(BuildingInfo.Role.Dining)
	if (diningHalls.is_empty()):
		return index
	var kind: Problem.Kind
	var small: String
	var accentName: String
	if (university.hasProblem(Problem.Kind.DiningUnfed)):
		kind = Problem.Kind.DiningUnfed
		small = DiningUnfedSmall
		accentName = AccentBad
	elif (university.hasProblem(Problem.Kind.DiningCrowded)):
		kind = Problem.Kind.DiningCrowded
		small = DiningCrowdedSmall
		accentName = AccentWarn
	else:
		return index
	var point: Vector2 = Campus.centroid(diningHalls)
	var text: String = DiningLoadFormat % NumberFormat.percent(university.diningLoad())
	var marker: CampusMarker = _place(index, point, text, small, accentName)
	marker.building = null
	marker.problemKind = kind
	return index + 1


## One marker per building still going up, over its own position.
func _placeConstruction(index: int) -> int:
	var used: int = index
	for building: Building in university.campus.buildings:
		if (not building.underConstruction):
			continue
		var text: String = OpensFormat % GameCalendar.periodLabel(building.opensAtMonth)
		var small: String = BuildingText.adds(building.info)
		var marker: CampusMarker = _place(used, building.pos, text, small, AccentInfo)
		marker.building = building
		used += 1
	return used


## Shows (or hides, while behind the camera) the pooled marker at index,
## anchored over point lifted to Building.Height.
func _place(index: int, point: Vector2, text: String, small: String, accentName: String) -> CampusMarker:
	var marker: CampusMarker = _markerAt(index)
	var world: Vector3 = Vector3(point.x, Building.Height, point.y)
	if (camera.is_position_behind(world)):
		marker.visible = false
		return marker
	marker.visible = true
	marker.display(text, small, accentName)
	marker.anchorAt(camera.unproject_position(world))
	return marker


func _markerAt(index: int) -> CampusMarker:
	if (index >= _pool.size()):
		var marker: CampusMarker = MarkerScene.instantiate()
		add_child(marker)
		marker.Activated.connect(_onActivated.bind(marker))
		_pool.append(marker)
	return _pool[index]


func _onActivated(marker: CampusMarker) -> void:
	if (marker.building != null):
		BuildingWanted.emit(marker.building)
	else:
		ProblemWanted.emit(marker.problemKind)
