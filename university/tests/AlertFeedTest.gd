extends GdUnitTestSuite
## The alerts list's rules. Problems and events are arbitrary fixtures.

const FirstWeek: int = 3
const LaterWeek: int = 7
const Count: int = 10
const Share: float = 0.5


func _overflow() -> Array[Problem]:
	var problems: Array[Problem] = [Problem.new(Problem.Kind.HousingOverflow, Count, Share)]
	return problems


func _none() -> Array[Problem]:
	var problems: Array[Problem] = []
	return problems


func test_a_problem_shows_while_it_holds_dated_when_it_appeared() -> void:
	var feed: AlertFeed = AlertFeed.new()
	feed.update(_overflow(), FirstWeek)
	feed.update(_overflow(), LaterWeek)
	assert_int(feed.shown().size()).is_equal(1)
	assert_int(feed.shown()[0].week).is_equal(FirstWeek)
	feed.update(_none(), LaterWeek)
	assert_array(feed.shown()).is_empty()


func test_a_dismissed_problem_stays_hidden_until_it_clears() -> void:
	var feed: AlertFeed = AlertFeed.new()
	feed.update(_overflow(), FirstWeek)
	feed.dismiss(feed.shown()[0])
	feed.update(_overflow(), LaterWeek)
	assert_array(feed.shown()).is_empty()
	feed.update(_none(), LaterWeek)
	feed.update(_overflow(), LaterWeek)
	assert_int(feed.shown().size()).is_equal(1)
	assert_int(feed.shown()[0].week).is_equal(LaterWeek)


func test_events_show_newest_first_and_the_oldest_drop_off() -> void:
	var feed: AlertFeed = AlertFeed.new()
	for week: int in range(AlertFeed.MaxEvents + 1):
		feed.addEvent(AlertEntry.new(AlertEntry.Source.AutoBorrowed, week))
	var lines: Array[AlertEntry] = feed.shown()
	assert_int(lines.size()).is_equal(AlertFeed.MaxEvents)
	assert_int(lines[0].week).is_equal(AlertFeed.MaxEvents)
	assert_int(lines[lines.size() - 1].week).is_equal(1)


func test_problems_come_first_and_a_dismissed_event_is_gone() -> void:
	var feed: AlertFeed = AlertFeed.new()
	var event: AlertEntry = AlertEntry.new(AlertEntry.Source.AutoBorrowed, FirstWeek)
	feed.addEvent(event)
	feed.update(_overflow(), LaterWeek)
	assert_int(feed.shown()[0].source).is_equal(AlertEntry.Source.Problem)
	feed.dismiss(event)
	assert_int(feed.shown().size()).is_equal(1)
	assert_int(feed.shown()[0].source).is_equal(AlertEntry.Source.Problem)
