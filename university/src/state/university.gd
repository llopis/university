class_name University
## The institution being run: its name and its campus. GameState holds one;
## everything the player runs hangs off it.

var name: String
var campus: Campus

# Keys toDict writes; fromDict refuses a dictionary missing any of them.
const SavedKeys: Array[String] = ["name", "campus"]


func _init() -> void:
	campus = Campus.new()


## A new month began. The campus opens whatever is due.
func startMonth(newMonth: int) -> void:
	campus.startMonth(newMonth)


func toDict() -> Dictionary:
	return {"name": name, "campus": campus.toDict()}


## Null when data is missing a key, or its campus refused.
static func fromDict(data: Dictionary, buildingDB: BuildingInfoDB) -> University:
	if (not Variants.hasKeys(data, SavedKeys, "University")):
		return null
	var campus: Campus = Campus.fromDict(data["campus"] as Dictionary, buildingDB)
	if (campus == null):
		return null
	var university: University = University.new()
	university.name = str(data["name"])
	university.campus = campus
	return university
