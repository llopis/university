class_name University
## The institution being run: its name, its money and its campus. GameState
## holds one; everything the player runs hangs off it. The campus spends from
## the university's finances, so the two are made together.

var name: String
var finances: Finances
var campus: Campus

# Keys toDict writes; fromDict refuses a dictionary missing any of them.
const SavedKeys: Array[String] = ["name", "finances", "campus"]


func _init() -> void:
	finances = Finances.new()
	campus = Campus.new(finances)


## A new month began. The campus opens whatever is due, then the month's bill is
## charged: the upkeep of every open building (including any that just opened)
## and the interest on the debt.
func startMonth(newMonth: int) -> void:
	campus.startMonth(newMonth)
	finances.charge(campus.upkeep() + finances.interest())


func toDict() -> Dictionary:
	return {"name": name, "finances": finances.toDict(), "campus": campus.toDict()}


## Null when data is missing a key, or its finances or campus refused. The
## finances are loaded first and handed to the campus, so the loaded campus
## spends from the loaded finances.
static func fromDict(data: Dictionary, buildingDB: BuildingInfoDB) -> University:
	if (not Variants.hasKeys(data, SavedKeys, "University")):
		return null
	var loadedFinances: Finances = Finances.fromDict(data["finances"] as Dictionary)
	if (loadedFinances == null):
		return null
	var loadedCampus: Campus = Campus.fromDict(data["campus"] as Dictionary, buildingDB, loadedFinances)
	if (loadedCampus == null):
		return null
	var university: University = University.new()
	university.name = str(data["name"])
	university.finances = loadedFinances
	university.campus = loadedCampus
	return university
