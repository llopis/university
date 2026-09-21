class_name BuildingView
extends MeshInstance3D
## A building drawn as a box, until models exist: the footprint from state,
## extruded to Building.Height. Also the placement ghost, which is the same
## box with a translucent material and no building behind it.

enum Highlight { None, Selected, Destroy }

const BaseColor: Color = Color(0.86, 0.82, 0.74)
const SelectedColor: Color = Color(1.0, 0.86, 0.4)
const DestroyColor: Color = Color(0.9, 0.32, 0.27)
const GhostValidColor: Color = Color(0.45, 0.9, 0.5, 0.55)
const GhostInvalidColor: Color = Color(0.95, 0.3, 0.25, 0.55)
const ConstructionAlpha: float = 0.45

var _material: StandardMaterial3D = StandardMaterial3D.new()
var _highlight: Highlight = Highlight.None
var _underConstruction: bool = false


static func create(forBuilding: Building) -> BuildingView:
	var view: BuildingView = BuildingView.new()
	view._setup()
	view.showRect(forBuilding.rect())
	view.setUnderConstruction(forBuilding.underConstruction)
	return view


static func createGhost() -> BuildingView:
	var view: BuildingView = BuildingView.new()
	view._setup()
	view._material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.setValid(true)
	return view


func _setup() -> void:
	mesh = BoxMesh.new()
	material_override = _material


## Shapes and places the box over a footprint. The one place a state angle
## becomes a node rotation: state turns from +X toward +Z, a node's y rotation
## turns from +X toward -Z.
func showRect(rect: OrientedRect) -> void:
	var box: BoxMesh = mesh as BoxMesh
	box.size = Vector3(rect.size.x, Building.Height, rect.size.y)
	position = Vector3(rect.center.x, Building.Height / 2.0, rect.center.y)
	rotation = Vector3(0.0, -rect.angle, 0.0)


func setHighlight(kind: Highlight) -> void:
	_highlight = kind
	_refresh()


## Under construction draws see-through and casts no shadow; open is solid.
func setUnderConstruction(value: bool) -> void:
	_underConstruction = value
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if (value) else BaseMaterial3D.TRANSPARENCY_DISABLED
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if (value) else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_refresh()


# The one place a building's colour is decided: the highlight picks the hue,
# construction the opacity.
func _refresh() -> void:
	var color: Color = BaseColor
	match _highlight:
		Highlight.Selected:
			color = SelectedColor
		Highlight.Destroy:
			color = DestroyColor
	color.a = ConstructionAlpha if (_underConstruction) else 1.0
	_material.albedo_color = color


func setValid(valid: bool) -> void:
	_material.albedo_color = GhostValidColor if (valid) else GhostInvalidColor
