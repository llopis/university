class_name University
## The institution being run: its name, money, campus, students and policy,
## and the standing they earn (reputation, satisfaction). GameState holds one;
## everything the player runs hangs off it. The campus spends from the
## university's finances, so the two are made together. _init makes parts only:
## it connects nothing, so fromDict can swap loaded parts in safely.

## A semester began: what happened, for the popup and the history.
signal SemesterStarted(report: SemesterReport)

var name: String
var finances: Finances
var campus: Campus
var students: StudentBody
var policy: Policy
# 0 to UniversityRules.MaxScore; steps each fall start.
var reputation: float = UniversityRules.ReputationReference
# This academic year's satisfaction, one sample per semester start.
var satisfactionSamples: Array[float]
# The weakest admit's grade in the latest fall that admitted anyone.
var lastIntakeGrade: float = UniversityRules.GradeBase
# Every semester start so far, oldest first.
var reports: Array[SemesterReport]

# Keys toDict writes; fromDict refuses a dictionary missing any of them.
const SavedKeys: Array[String] = ["name", "finances", "campus"]


func _init() -> void:
	finances = Finances.new()
	campus = Campus.new(finances)
	students = StudentBody.new()
	policy = Policy.new()


## A new month began. The campus opens whatever is due; at a semester start the
## semester runs (see _startSemester); last, the month's bill is charged, after
## any fees so the fees pay it.
func startMonth(newMonth: int) -> void:
	var opened: Array[Building] = campus.startMonth(newMonth)
	if (GameCalendar.isSemesterStart(newMonth)):
		_startSemester(newMonth, opened)
	finances.charge(monthlyExpenses())


## What a month costs: every open building's upkeep and the interest on the
## debt. The one source of the monthly bill.
func monthlyExpenses() -> int:
	return campus.upkeep() + finances.interest()


func housed() -> int:
	return UniversityRules.housed(students.enrolled(), campus.beds())


func mealPlans() -> int:
	return UniversityRules.mealPlans(housed(), campus.meals())


func satisfactionNow() -> Satisfaction:
	return UniversityRules.satisfaction(students.enrolled(), housed(), campus.meals())


## Where the next fall start will step reputation toward: the latest intake's
## grade and this year's mean satisfaction (today's, before any sample).
func reputationTarget() -> float:
	return UniversityRules.reputationTarget(lastIntakeGrade, _yearSatisfaction())


func _yearSatisfaction() -> float:
	if (satisfactionSamples.is_empty()):
		return satisfactionNow().total()
	var sum: float = 0.0
	for sample: float in satisfactionSamples:
		sum += sample
	return sum / float(satisfactionSamples.size())


## A semester start: every cohort completes a semester and the finished ones
## graduate; in fall the year begins (see _startYear); then satisfaction is
## sampled and the fees come in. Kept as a report and announced.
func _startSemester(semesterMonth: int, opened: Array[Building]) -> void:
	var report: SemesterReport = SemesterReport.new()
	report.month = semesterMonth
	report.isFall = GameCalendar.isFallStart(semesterMonth)
	var reputationBefore: float = reputation
	var satisfactionBefore: float = reports[reports.size() - 1].satisfaction if (not reports.is_empty()) else satisfactionNow().total()
	report.graduated = students.completeSemester()
	if (report.isFall):
		_startYear(report)
	var sampled: float = satisfactionNow().total()
	satisfactionSamples.append(sampled)
	var fees: Fees = UniversityRules.fees(policy.current, students.enrolled(), housed(), mealPlans())
	finances.receive(fees.total())
	report.enrolled = students.enrolled()
	report.housed = housed()
	report.beds = campus.beds()
	report.mealPlans = mealPlans()
	report.diningLoad = UniversityRules.diningLoad(report.housed, campus.meals())
	report.tuitionFees = fees.tuition
	report.roomFees = fees.room
	report.mealFees = fees.meals
	report.reputation = reputation
	report.reputationChange = reputation - reputationBefore
	report.satisfaction = sampled
	report.satisfactionChange = sampled - satisfactionBefore
	report.cash = finances.cash
	report.debt = finances.debt
	for building: Building in opened:
		report.opened.append(building.info.name)
	reports.append(report)
	SemesterStarted.emit(report)


## The fall start: reputation takes its yearly step on the year just ended, the
## year's prices lock, and the new class is admitted into the open seats.
func _startYear(report: SemesterReport) -> void:
	reputation = UniversityRules.nextReputation(reputation, reputationTarget())
	satisfactionSamples.clear()
	var hasOffice: bool = campus.hasOpenAdmissionsOffice()
	policy.lockYear(hasOffice)
	report.applicants = UniversityRules.applicants(reputation, policy.current.total())
	report.openSeats = maxi(campus.seats() - students.enrolled(), 0)
	var intake: Intake = UniversityRules.admission(report.applicants, report.openSeats, policy.minimumInUse(hasOffice))
	students.admit(intake.admitted, intake.entryGrade)
	report.admitted = intake.admitted
	report.entryGrade = intake.entryGrade
	if (intake.admitted > 0):
		lastIntakeGrade = intake.entryGrade


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
