class_name SemesterReport
## What happened at one semester start, for the popup, the history and the
## console. The admission fields stay 0 in spring. Cash and debt are as they
## stood after the fees came in, before that month's bill.

# Keys toDict writes; fromDict refuses a dictionary missing any of them.
const SavedKeys: Array[String] = [
	"month", "isFall", "applicants", "openSeats", "admitted", "entryGrade", "graduated",
	"enrolled", "housed", "beds", "mealPlans", "diningLoad",
	"tuitionFees", "roomFees", "mealFees",
	"reputation", "reputationChange", "satisfaction", "satisfactionChange",
	"cash", "debt", "opened"]

var month: int = 0
var isFall: bool = false
var applicants: int = 0
var openSeats: int = 0
var admitted: int = 0
var entryGrade: float = 0.0
var graduated: int = 0
var enrolled: int = 0
var housed: int = 0
var beds: int = 0
var mealPlans: int = 0
var diningLoad: float = 0.0
var tuitionFees: int = 0
var roomFees: int = 0
var mealFees: int = 0
var reputation: float = 0.0
var reputationChange: float = 0.0
var satisfaction: float = 0.0
var satisfactionChange: float = 0.0
var cash: int = 0
var debt: int = 0
# Names of the buildings that opened at this start.
var opened: Array[String]


func offCampus() -> int:
	return enrolled - housed


func offCampusShare() -> float:
	return UniversityRules.offCampusShare(enrolled, housed)


func unfed() -> int:
	return housed - mealPlans


func totalFees() -> int:
	return tuitionFees + roomFees + mealFees


func toDict() -> Dictionary:
	return {
		"month": month, "isFall": isFall, "applicants": applicants, "openSeats": openSeats,
		"admitted": admitted, "entryGrade": entryGrade, "graduated": graduated,
		"enrolled": enrolled, "housed": housed, "beds": beds, "mealPlans": mealPlans,
		"diningLoad": diningLoad, "tuitionFees": tuitionFees, "roomFees": roomFees,
		"mealFees": mealFees, "reputation": reputation, "reputationChange": reputationChange,
		"satisfaction": satisfaction, "satisfactionChange": satisfactionChange,
		"cash": cash, "debt": debt, "opened": opened.duplicate(),
	}


## Null when data is missing a key.
static func fromDict(data: Dictionary) -> SemesterReport:
	if (not Variants.hasKeys(data, SavedKeys, "SemesterReport")):
		return null
	var report: SemesterReport = SemesterReport.new()
	report.month = Variants.toInt(data["month"])
	report.isFall = Variants.toBool(data["isFall"])
	report.applicants = Variants.toInt(data["applicants"])
	report.openSeats = Variants.toInt(data["openSeats"])
	report.admitted = Variants.toInt(data["admitted"])
	report.entryGrade = Variants.toFloat(data["entryGrade"])
	report.graduated = Variants.toInt(data["graduated"])
	report.enrolled = Variants.toInt(data["enrolled"])
	report.housed = Variants.toInt(data["housed"])
	report.beds = Variants.toInt(data["beds"])
	report.mealPlans = Variants.toInt(data["mealPlans"])
	report.diningLoad = Variants.toFloat(data["diningLoad"])
	report.tuitionFees = Variants.toInt(data["tuitionFees"])
	report.roomFees = Variants.toInt(data["roomFees"])
	report.mealFees = Variants.toInt(data["mealFees"])
	report.reputation = Variants.toFloat(data["reputation"])
	report.reputationChange = Variants.toFloat(data["reputationChange"])
	report.satisfaction = Variants.toFloat(data["satisfaction"])
	report.satisfactionChange = Variants.toFloat(data["satisfactionChange"])
	report.cash = Variants.toInt(data["cash"])
	report.debt = Variants.toInt(data["debt"])
	for buildingName: Variant in data["opened"] as Array:
		report.opened.append(str(buildingName))
	return report
