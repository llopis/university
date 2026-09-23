class_name Policy
## What the university charges and whom it admits. Prices are set a year
## ahead: the player sets `next`, and each fall start makes it `current` for
## the whole academic year. The Admissions Office grants the levers: with none
## open, the defaults apply and there is no minimum grade.

# UMass 2026-27 in-state, per semester.
const DefaultTuition: int = 9606
const DefaultRoom: int = 4542
const DefaultMealPlan: int = 4136
# Keys toDict writes; fromDict refuses a dictionary missing any of them.
const SavedKeys: Array[String] = ["current", "next", "minimumGrade"]

# The Admissions Office steppers' increments: prices move PriceStep dollars at a
# time, the minimum GradeStep of a grade.
const PriceStep: int = 100
const GradeStep: float = 0.1
# Half a step: how close to GradeBase still counts as at it, against float drift.
const GradeSlack: float = GradeStep / 2.0

var current: Prices
var next: Prices
# 0 is off.
var minimumGrade: float = 0.0


func _init() -> void:
	current = Policy.defaultPrices()
	next = Policy.defaultPrices()


static func defaultPrices() -> Prices:
	return Prices.new(DefaultTuition, DefaultRoom, DefaultMealPlan)


func setNextTuition(amount: int) -> void:
	next.tuition = maxi(amount, 0)


func setNextRoom(amount: int) -> void:
	next.room = maxi(amount, 0)


func setNextMealPlan(amount: int) -> void:
	next.mealPlan = maxi(amount, 0)


func setMinimumGrade(grade: float) -> void:
	minimumGrade = clampf(grade, 0.0, UniversityRules.MaxGrade)


## Moves next year's tuition a step: up for direction 1, down for -1.
func stepNextTuition(direction: int) -> void:
	setNextTuition(next.tuition + direction * PriceStep)


func stepNextRoom(direction: int) -> void:
	setNextRoom(next.room + direction * PriceStep)


func stepNextMealPlan(direction: int) -> void:
	setNextMealPlan(next.mealPlan + direction * PriceStep)


## Moves the minimum grade a step. From off, a step up starts it at
## UniversityRules.GradeBase, the cutoff when applicants equal seats; a step
## below that turns it off again, since a minimum under the cutoff trims nobody.
func stepMinimum(direction: int) -> void:
	if (minimumGrade <= 0.0):
		if (direction > 0):
			setMinimumGrade(UniversityRules.GradeBase)
		return
	var stepped: float = roundf((minimumGrade + float(direction) * GradeStep) / GradeStep) * GradeStep
	setMinimumGrade(stepped if (stepped >= UniversityRules.GradeBase - GradeSlack) else 0.0)


## The fall start: next year's prices become this year's, or the defaults when
## no Admissions Office is open.
func lockYear(hasOffice: bool) -> void:
	current = pricesFor(hasOffice)


## The prices a fall start locks in: next year's, or the defaults with no
## Admissions Office. The one rule for "what next fall will charge".
func pricesFor(hasOffice: bool) -> Prices:
	return next.copy() if (hasOffice) else Policy.defaultPrices()


## The minimum the fall admission applies: none without an Admissions Office.
func minimumInUse(hasOffice: bool) -> float:
	return minimumGrade if (hasOffice) else 0.0


func toDict() -> Dictionary:
	return {"current": current.toDict(), "next": next.toDict(), "minimumGrade": minimumGrade}


## Null when data, or either set of prices in it, is missing a key.
static func fromDict(data: Dictionary) -> Policy:
	if (not Variants.hasKeys(data, SavedKeys, "Policy")):
		return null
	var loadedCurrent: Prices = Prices.fromDict(data["current"] as Dictionary)
	if (loadedCurrent == null):
		return null
	var loadedNext: Prices = Prices.fromDict(data["next"] as Dictionary)
	if (loadedNext == null):
		return null
	var policy: Policy = Policy.new()
	policy.current = loadedCurrent
	policy.next = loadedNext
	policy.setMinimumGrade(Variants.toFloat(data["minimumGrade"]))
	return policy
