class_name BuildingInfoDB
## id -> BuildingInfo plus the sheet-ordered list (build-menu order). The sole
## source of building definitions.

# Reported and dropped: a footprint needs a size before anything can stand on
# it, overlap it or be picked out of it.
const NoDiameterError: String = "BuildingInfoDB: building type '%s' has no positive diameter; leaving it out."

var db: Dictionary[String, BuildingInfo]
var all: Array[BuildingInfo]


func _init(records: Array[Dictionary]) -> void:
	for data: Dictionary in records:
		var buildingInfo: BuildingInfo = BuildingInfo.new(data)
		if (buildingInfo.diameter <= 0.0):
			push_error(NoDiameterError % buildingInfo.id)
			continue
		db[buildingInfo.id] = buildingInfo
		all.append(buildingInfo)


func info(id: String) -> BuildingInfo:
	return db.get(id) as BuildingInfo


## The categories in the order the sheet first uses them: the build panel's tabs.
func categories() -> Array[String]:
	var found: Array[String] = []
	for buildingInfo: BuildingInfo in all:
		if (not found.has(buildingInfo.category)):
			found.append(buildingInfo.category)
	return found


## The types in one category, in sheet order.
func inCategory(category: String) -> Array[BuildingInfo]:
	var found: Array[BuildingInfo] = []
	for buildingInfo: BuildingInfo in all:
		if (buildingInfo.category == category):
			found.append(buildingInfo)
	return found


# Named loadFrom (not load) to avoid shadowing GDScript's global load().
static func loadFrom(path: String) -> BuildingInfoDB:
	return BuildingInfoDB.new(CsvLoader.load_csv(path))
