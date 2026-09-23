class_name UniversityMenu
extends PanelContainer
## The university's own directory: the Admissions Office, the finances,
## reputation, housing and dining. A building-backed entry selects its building
## and moves the camera to it; it is disabled while none is open.

signal FinancesChosen
signal ReputationChosen
signal HousingChosen
signal BuildingChosen(building: Building)

const DormFormat: String = "%d dorm"
const DormsFormat: String = "%d dorms"
const HallFormat: String = "%d hall"
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
	admissionsButton.pressed.connect(func() -> void: _chooseFirst(university.campus.openWithRole(BuildingInfo.Role.Admissions)))
	diningButton.pressed.connect(func() -> void: _chooseFirst(university.campus.openWithRole(BuildingInfo.Role.Dining)))


func _process(_dt: float) -> void:
	if (university == null or not visible):
		return
	var dorms: int = university.campus.openWithRole(BuildingInfo.Role.Housing).size()
	var halls: int = university.campus.openWithRole(BuildingInfo.Role.Dining).size()
	housingCount.text = (DormFormat if (dorms == 1) else DormsFormat) % dorms
	diningCount.text = (HallFormat if (halls == 1) else HallsFormat) % halls
	admissionsButton.disabled = not university.campus.hasOpenAdmissionsOffice()
	diningButton.disabled = (halls == 0)
	_tint(admissionsDot, &"good" if (university.campus.hasOpenAdmissionsOffice()) else &"dim")
	_tint(housingDot, &"warn" if (university.hasProblem(Problem.Kind.HousingOverflow)) else &"dim")
	var diningTone: UiTone.Tone = DiningLoadLine.toneFor(university)
	_tint(diningDot, &"bad" if (diningTone == UiTone.Tone.Bad) else (&"warn" if (diningTone == UiTone.Tone.Warn) else &"dim"))


func _chooseFirst(buildings: Array[Building]) -> void:
	if (not buildings.is_empty()):
		BuildingChosen.emit(buildings[0])


func _tint(dot: Panel, colorName: StringName) -> void:
	dot.self_modulate = get_theme_color(colorName, &"Palette")
