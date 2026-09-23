class_name UniversityRules
## The student loop's rules and tuning, as pure functions: how many apply, who
## is admitted and at what grade, where students live and eat, how satisfied
## they are, and how reputation moves. Every tuning value is a named const
## here; they are starting points for tuning, not decisions.

# Applicants: every ReputationDoubling points of reputation doubles them, and
# every PriceHalving dollars of total price above ReferencePrice halves them.
# The pool is sized to the start campus: at its balance point about 2.5 apply
# for each open seat.
const ApplicantPool: float = 335.0
const ReputationReference: float = 50.0
const ReputationDoubling: float = 20.0
const ReferencePrice: float = 18300.0
const PriceHalving: float = 6000.0
# Grades are GPA, 0 to MaxGrade. The weakest admit's grade is GradeBase when
# applicants equal open seats, and rises GradeSpread per factor of e beyond.
const GradeBase: float = 2.8
const GradeSpread: float = 0.35
const MaxGrade: float = 4.0
# Satisfaction and reputation are scores from 0 to MaxScore.
const MaxScore: float = 100.0
const GradeToScore: float = MaxScore / MaxGrade
# Satisfaction has only penalties so far, so its base sits below the top.
const SatisfactionBase: float = 75.0
const OverflowThreshold: float = 0.25
const OverflowWeight: float = 100.0
const CrowdingWeight: float = 50.0
const DiningHardLimit: float = 1.3
const UnfedWeight: float = 150.0
const ReputationRate: float = 0.3
const ReputationGradeWeight: float = 0.5
const Doubling: float = 2.0


## How many apply at a fall start.
static func applicants(reputation: float, totalPrice: int) -> int:
	var fromReputation: float = pow(Doubling, (reputation - ReputationReference) / ReputationDoubling)
	var fromPrice: float = pow(Doubling, -(float(totalPrice) - ReferencePrice) / PriceHalving)
	return floori(ApplicantPool * fromReputation * fromPrice)


## Who is admitted from the applicants into the open seats, and the grade of the
## weakest one admitted. The class trails off above that cutoff, so a minimum
## above it trims the class along the same spread: it always trades students
## for grade. No seats or no applicants admits nobody.
static func admission(applicantCount: int, openSeats: int, minimum: float) -> Intake:
	if (applicantCount <= 0 or openSeats <= 0):
		return Intake.new(0, 0.0)
	var cutoff: float = clampf(GradeBase + GradeSpread * log(float(applicantCount) / float(openSeats)), 0.0, MaxGrade)
	var kept: float = exp(-maxf(0.0, minimum - cutoff) / GradeSpread)
	return Intake.new(floori(float(mini(applicantCount, openSeats)) * kept), maxf(cutoff, minimum))


## Students in a bed on campus; the rest live off campus.
static func housed(enrolled: int, beds: int) -> int:
	return mini(enrolled, beds)


## Housed students who eat on campus: all of them, up to DiningHardLimit times
## what the dining halls are meant for. Past that the rest can't eat, and buy
## no meal plan. Off-campus students buy none either.
static func mealPlans(housedCount: int, meals: int) -> int:
	return mini(housedCount, floori(DiningHardLimit * float(meals)))


## Housed students per diner the dining halls are meant for. With no dining
## hall it is measured against one, so it reads as hopelessly over.
static func diningLoad(housedCount: int, meals: int) -> float:
	return float(housedCount) / float(maxi(meals, 1))


static func satisfaction(enrolled: int, housedCount: int, meals: int) -> Satisfaction:
	var result: Satisfaction = Satisfaction.new()
	result.base = SatisfactionBase
	if (enrolled <= 0):
		return result
	var plans: int = mealPlans(housedCount, meals)
	var perStudent: float = 1.0 / float(enrolled)
	result.housing = OverflowWeight * maxf(0.0, float(enrolled - housedCount) * perStudent - OverflowThreshold)
	result.crowding = CrowdingWeight * clampf(diningLoad(housedCount, meals) - 1.0, 0.0, DiningHardLimit - 1.0) * float(plans) * perStudent
	result.unfed = UnfedWeight * float(housedCount - plans) * perStudent
	return result


## Where reputation heads: half the latest intake's grade (as a score), half the
## year's satisfaction, weighted by ReputationGradeWeight.
static func reputationTarget(intakeGrade: float, meanSatisfaction: float) -> float:
	return ReputationGradeWeight * intakeGrade * GradeToScore + (1.0 - ReputationGradeWeight) * meanSatisfaction


## A fall's step: ReputationRate of the way to the target.
static func nextReputation(reputation: float, target: float) -> float:
	return clampf(reputation + ReputationRate * (target - reputation), 0.0, MaxScore)


static func fees(prices: Prices, enrolled: int, housedCount: int, plans: int) -> Fees:
	var result: Fees = Fees.new()
	result.tuition = prices.tuition * enrolled
	result.room = prices.room * housedCount
	result.meals = prices.mealPlan * plans
	return result


## Once round grades → reputation → applicants: how much of an extra point of
## reputation comes back as target. Below 1 the loop settles by itself.
static func loopGain() -> float:
	return ReputationGradeWeight * GradeToScore * GradeSpread * log(Doubling) / ReputationDoubling
