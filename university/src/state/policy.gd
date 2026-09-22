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


## The fall start: next year's prices become this year's, or the defaults when
## no Admissions Office is open.
func lockYear(hasOffice: bool) -> void:
	current = next.copy() if (hasOffice) else Policy.defaultPrices()


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
