class_name GameCalendar
## The one place a month index becomes dates and semesters. A month index
## counts months since the game began (0 is September of the first year);
## everything here is derived from it, so nothing else needs to know how long
## a month or a year is.

# Sim seconds in one month at 1x speed.
const SecondsPerMonth: float = 45.0
const MonthsPerYear: int = 12
const MonthNames: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
# Calendar months, 0 = January.
const February: int = 1
const September: int = 8
# The game opens at the start of the academic year, and years are academic:
# the year number goes up each September.
const StartMonth: int = September
const SemesterStartMonths: Array[int] = [September, February]
const FirstYear: int = 1
# Four weeks a month: a 48-week year.
const WeeksPerMonth: int = 4
## How the year reads on the clock. Summer is only a label: the sim has two
## semester starts, September and February.
enum Period { Fall, Spring, Summer }
const PeriodNames: Array[String] = ["Fall", "Spring", "Summer"]
# Calendar months (0 = January) each period starts at.
const June: int = 5
const PeriodStartMonths: Array[int] = [September, February, June]


## The calendar month (0 = January) of a month index.
static func calendarMonth(monthIndex: int) -> int:
	return (StartMonth + monthIndex) % MonthsPerYear


static func year(monthIndex: int) -> int:
	return FirstYear + floori(float(monthIndex) / float(MonthsPerYear))


static func monthName(monthIndex: int) -> String:
	return MonthNames[calendarMonth(monthIndex)]


static func label(monthIndex: int) -> String:
	return "%s, Year %d" % [monthName(monthIndex), year(monthIndex)]


static func isSemesterStart(monthIndex: int) -> bool:
	return SemesterStartMonths.has(calendarMonth(monthIndex))


## A September: the fall start, when the year's prices lock and a class is admitted.
static func isFallStart(monthIndex: int) -> bool:
	return calendarMonth(monthIndex) == September


## The first semester start strictly after a month: a month that itself starts
## a semester looks ahead to the following one.
static func nextSemesterStart(monthIndex: int) -> int:
	var next: int = monthIndex + 1
	while (not isSemesterStart(next)):
		next += 1
	return next


## The first fall start strictly after a month: a month that itself starts a
## fall looks ahead to the following one.
static func nextFallStart(monthIndex: int) -> int:
	var next: int = monthIndex + 1
	while (not isFallStart(next)):
		next += 1
	return next


## How many semester starts fall after fromMonth and at or before toMonth.
static func semesterStartsBetween(fromMonth: int, toMonth: int) -> int:
	var count: int = 0
	for monthIndex: int in range(fromMonth + 1, toMonth + 1):
		if (isSemesterStart(monthIndex)):
			count += 1
	return count


static func period(monthIndex: int) -> Period:
	var calendar: int = calendarMonth(monthIndex)
	if (calendar >= September or calendar < February):
		return Period.Fall
	if (calendar < June):
		return Period.Spring
	return Period.Summer


## "Fall, Year 4": the period and the academic year.
static func periodLabel(monthIndex: int) -> String:
	return "%s, Year %d" % [PeriodNames[period(monthIndex)], year(monthIndex)]


## Months into its period: 0 in the period's first month.
static func _monthsIntoPeriod(monthIndex: int) -> int:
	var start: int = PeriodStartMonths[period(monthIndex)]
	return (calendarMonth(monthIndex) - start + MonthsPerYear) % MonthsPerYear


## How long a month's period lasts, in weeks.
static func weeksInPeriod(monthIndex: int) -> int:
	var months: int = 0
	var probe: int = monthIndex - _monthsIntoPeriod(monthIndex)
	var here: Period = period(monthIndex)
	while (period(probe + months) == here):
		months += 1
	return months * WeeksPerMonth


static func _monthOfWeek(weekIndex: int) -> int:
	return floori(float(weekIndex) / float(WeeksPerMonth))


## The week within its period, counting from 1.
static func weekInPeriod(weekIndex: int) -> int:
	var monthIndex: int = _monthOfWeek(weekIndex)
	return _monthsIntoPeriod(monthIndex) * WeeksPerMonth + (weekIndex - monthIndex * WeeksPerMonth) + 1


## Weeks until the next period's first week: 1 in a period's last week.
static func weeksToNextPeriod(weekIndex: int) -> int:
	return weeksInPeriod(_monthOfWeek(weekIndex)) - weekInPeriod(weekIndex) + 1


static func nextPeriodName(monthIndex: int) -> String:
	return PeriodNames[(period(monthIndex) + 1) % PeriodNames.size()]


## Weeks from this week until a month's first week.
static func weeksUntil(weekIndex: int, monthIndex: int) -> int:
	return monthIndex * WeeksPerMonth - weekIndex


## "Week 9 of 20 · Spring in 12 weeks".
static func clockLine(weekIndex: int) -> String:
	var monthIndex: int = _monthOfWeek(weekIndex)
	var left: int = weeksToNextPeriod(weekIndex)
	return "Week %d of %d · %s in %d %s" % [
		weekInPeriod(weekIndex), weeksInPeriod(monthIndex), nextPeriodName(monthIndex),
		left, "week" if (left == 1) else "weeks"]
