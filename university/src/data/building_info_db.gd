class_name BuildingInfoDB
## id -> BuildingInfo plus the sheet-ordered list (build-menu order). The sole
## source of building definitions.

var db: Dictionary[String, BuildingInfo]
var all: Array[BuildingInfo]


func _init(records: Array[Dictionary]) -> void:
	for data: Dictionary in records:
		var buildingInfo: BuildingInfo = BuildingInfo.new(data)
		db[buildingInfo.id] = buildingInfo
		all.append(buildingInfo)


func info(id: String) -> BuildingInfo:
	return db.get(id) as BuildingInfo


# Named loadFrom (not load) to avoid shadowing GDScript's global load().
static func loadFrom(path: String) -> BuildingInfoDB:
	return BuildingInfoDB.new(CsvLoader.load_csv(path))
