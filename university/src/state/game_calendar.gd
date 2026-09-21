class_name GameCalendar
## The one place sim time becomes dates. A month index counts months since the
## game began (0 is September of the first year); everything here is derived
## from it, so nothing else needs to know how long a month or a year is.

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


## The first semester start strictly after a month: a month that itself starts
## a semester looks ahead to the following one.
static func nextSemesterStart(monthIndex: int) -> int:
	var next: int = monthIndex + 1
	while (not isSemesterStart(next)):
		next += 1
	return next
