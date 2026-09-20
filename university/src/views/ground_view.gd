class_name GroundView
extends MeshInstance3D
## The campus ground: one plane as large as the campus. The grid on it is the
## material's doing (ground.gdshader).


func _ready() -> void:
	var plane: PlaneMesh = mesh as PlaneMesh
	plane.size = Vector2(Campus.Size, Campus.Size)
