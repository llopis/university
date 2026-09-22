class_name University
## The institution being run: its name and its campus. GameState holds one;
## everything the player runs hangs off it.

var name: String
var campus: Campus


func _init() -> void:
	campus = Campus.new()


## A new month began. The campus opens whatever is due.
func startMonth(newMonth: int) -> void:
	campus.startMonth(newMonth)


func toDict() -> Dictionary:
	return {"name": name, "campus": campus.toDict()}


static func fromDict(data: Dictionary, buildingDB: BuildingInfoDB) -> University:
	var university: University = University.new()
	university.name = str(data["name"])
	university.campus = Campus.fromDict(data["campus"] as Dictionary, buildingDB)
	return university
