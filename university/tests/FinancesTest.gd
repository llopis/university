extends GdUnitTestSuite
## The university's money: cash, debt and the credit line. Amounts are
## arbitrary fixtures; assertions are about the rules between them.

const Cash: int = 1000000
const Bill: int = 300000
const Borrowed: int = 2000000


func _finances(cash: int, debt: int) -> Finances:
	var finances: Finances = Finances.new()
	finances.setCash(cash)
	finances.setDebt(debt)
	return finances


func test_a_bill_the_cash_covers_is_paid_from_cash() -> void:
	var finances: Finances = _finances(Cash, 0)
	var borrowed: Array[int] = []
	finances.AutoBorrowed.connect(func(drawn: int, _charged: int) -> void: borrowed.append(drawn))
	finances.charge(Bill)
	assert_int(finances.cash).is_equal(Cash - Bill)
	assert_int(finances.debt).is_equal(0)
	assert_array(borrowed).is_empty()


func test_a_bill_past_the_cash_borrows_the_shortfall_and_a_fee() -> void:
	var finances: Finances = _finances(Bill, 0)
	var announced: Array[int] = []
	finances.AutoBorrowed.connect(func(drawn: int, charged: int) -> void: announced.append_array([drawn, charged]))
	finances.charge(Cash)
	var shortfall: int = Cash - Bill
	var fee: int = roundi(float(shortfall) * Finances.ShortfallFee)
	assert_int(finances.cash).is_equal(0)
	assert_int(finances.debt).is_equal(shortfall + fee)
	assert_array(announced).contains_exactly([shortfall, fee])


func test_the_automatic_draw_may_go_past_the_credit_limit() -> void:
	var finances: Finances = _finances(0, Finances.CreditLimit)
	finances.charge(Bill)
	assert_int(finances.debt).is_greater(Finances.CreditLimit)
	assert_int(finances.cash).is_equal(0)


func test_borrowing_stops_at_the_credit_limit() -> void:
	var finances: Finances = _finances(0, 0)
	assert_int(finances.borrow(Finances.CreditLimit + Borrowed)).is_equal(Finances.CreditLimit)
	assert_int(finances.debt).is_equal(Finances.CreditLimit)
	assert_int(finances.cash).is_equal(Finances.CreditLimit)
	assert_int(finances.borrow(Borrowed)).is_equal(0)
	assert_int(finances.availableCredit()).is_equal(0)


func test_repaying_is_capped_by_the_debt_and_the_cash() -> void:
	var finances: Finances = _finances(Cash, Borrowed)
	# Owes more than it holds: repays only what it holds.
	assert_int(finances.repay(Borrowed)).is_equal(Cash)
	assert_int(finances.cash).is_equal(0)
	assert_int(finances.debt).is_equal(Borrowed - Cash)
	# Holds more than it owes: repays only what it owes.
	finances.setCash(Borrowed * 2)
	assert_int(finances.repay(Borrowed * 2)).is_equal(Borrowed - Cash)
	assert_int(finances.debt).is_equal(0)


func test_interest_is_the_monthly_rate_on_the_debt() -> void:
	var finances: Finances = _finances(0, Borrowed)
	assert_int(finances.interest()).is_equal(roundi(float(Borrowed) * Finances.MonthlyInterestRate))
	assert_float(Finances.MonthlyInterestRate * GameCalendar.MonthsPerYear).is_equal_approx(Finances.AnnualInterestRate, 0.000001)
	assert_int(_finances(Cash, 0).interest()).is_equal(0)


func test_every_change_is_announced() -> void:
	var finances: Finances = _finances(Cash, 0)
	var changes: Array[int] = []
	finances.MoneyChanged.connect(func() -> void: changes.append(finances.cash))
	finances.spend(Bill)
	finances.refund(Bill)
	finances.borrow(Borrowed)
	finances.repay(Borrowed)
	finances.charge(Bill)
	assert_int(changes.size()).is_equal(5)


func test_a_round_trip_keeps_cash_and_debt() -> void:
	var finances: Finances = _finances(Cash, Borrowed)
	var back: Finances = Finances.fromDict(SaveFile.decode(SaveFile.encode(finances.toDict())) as Dictionary)
	assert_int(back.cash).is_equal(Cash)
	assert_int(back.debt).is_equal(Borrowed)


func test_a_save_missing_a_key_is_refused() -> void:
	var data: Dictionary = _finances(Cash, Borrowed).toDict()
	data.erase("debt")
	var loaded: Array[Finances] = []
	await assert_error(func() -> void: loaded.append(Finances.fromDict(data))) \
		.is_push_error(Variants.MissingKeysError % ["Finances", "debt"])
	assert_object(loaded[0]).is_null()
