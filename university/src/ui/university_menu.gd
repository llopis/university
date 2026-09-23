class_name UniversityMenu
extends PanelContainer
## The university's own directory: the Admissions Office, the finances,
## reputation, housing and dining. A building-backed entry selects its building
## and moves the camera to it; it is disabled while none is open.

signal FinancesChosen
signal ReputationChosen
signal HousingChosen
signal BuildingChosen(building: Building)

const DormsFormat: String = "%d dorms"
const HallsFormat: String = "%d halls"

@onready var admissionsButton: Button = %AdmissionsButton
@onready var financesButton: Button = %FinancesButton
@onready var reputationButton: Button = %ReputationButton
@onready var housingButton: Button = %HousingButton
@onready var diningButton: Button = %DiningButton
@onready var housingCount: Label = %HousingCount
@onready var diningCount: Label = %DiningCount
@onready var admissionsDot: Panel = %AdmissionsDot
@onready var housingDot: Panel = %HousingDot
@onready var diningDot: Panel = %DiningDot

var university: University


func _ready() -> void:
	financesButton.pressed.connect(func() -> void: FinancesChosen.emit())
	reputationButton.pressed.connect(func() -> void: ReputationChosen.emit())
	housingButton.pressed.connect(func() -> void: HousingChosen.emit())
	admissionsButton.pressed.connect(func() -> void: _chooseFirst(func(info: BuildingInfo) -> bool: return info.admissionsOffice))
	diningButton.pressed.connect(func() -> void: _chooseFirst(func(info: BuildingInfo) -> bool: return info.meals > 0))


func _process(_dt: float) -> void:
	if (university == null or not visible):
		return
	var dorms: int = _count(func(info: BuildingInfo) -> bool: return info.beds > 0)
	var halls: int = _count(func(info: BuildingInfo) -> bool: return info.meals > 0)
	housingCount.text = DormsFormat % dorms
	diningCount.text = HallsFormat % halls
	admissionsButton.disabled = not university.campus.hasOpenAdmissionsOffice()
	diningButton.disabled = (halls == 0)
	_tint(admissionsDot, &"good" if (university.campus.hasOpenAdmissionsOffice()) else &"dim")
	_tint(housingDot, &"warn" if (university.hasProblem(Problem.Kind.HousingOverflow)) else &"dim")
	_tint(diningDot, &"bad" if (university.hasProblem(Problem.Kind.DiningUnfed)) else (&"warn" if (university.hasProblem(Problem.Kind.DiningCrowded)) else &"dim"))


func _count(isKind: Callable) -> int:
	var total: int = 0
	for building: Building in university.campus.openBuildings():
		if (Variants.toBool(isKind.call(building.info))):
			total += 1
	return total


func _chooseFirst(isKind: Callable) -> void:
	for building: Building in university.campus.openBuildings():
		if (Variants.toBool(isKind.call(building.info))):
			BuildingChosen.emit(building)
			return


func _tint(dot: Panel, colorName: StringName) -> void:
	dot.self_modulate = get_theme_color(colorName, &"Palette")
