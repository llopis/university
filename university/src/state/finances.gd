class_name Finances
## The university's money: cash in hand and what it owes on its credit line,
## both whole dollars and never negative. `_write` is the one writer, so no
## balance changes unannounced. Building spends cash only: to build past the
## cash the player borrows first, up to CreditLimit. The monthly bill is the one
## exception to the limit: a bill the cash cannot cover borrows the shortfall
## automatically, plus a fee, however much is already owed. There is no
## bankruptcy.

signal MoneyChanged
## A monthly bill was more than the cash; the shortfall and the fee went on the
## credit line.
signal AutoBorrowed(shortfall: int, fee: int)

# Whole dollars the player may borrow in all. The automatic draw may go past it.
const CreditLimit: int = 50000000
const AnnualInterestRate: float = 0.06
# Charged each month on what is owed: the one place a year's rate becomes a month's.
const MonthlyInterestRate: float = AnnualInterestRate / GameCalendar.MonthsPerYear
# The cost of an automatic draw, as a fraction of the shortfall it covers.
const ShortfallFee: float = 0.05
# Whole dollars one Borrow or Repay button moves.
const LoanStep: int = 5000000
# Keys toDict writes; fromDict refuses a dictionary missing any of them.
const SavedKeys: Array[String] = ["cash", "debt"]

var cash: int = 0
var debt: int = 0


func canAfford(amount: int) -> bool:
	return amount <= cash


## What building costs. Callers check canAfford first: cash never goes negative.
func spend(amount: int) -> void:
	_write(cash - amount, debt)


## What destroying a building still under construction gives back.
func refund(amount: int) -> void:
	_write(cash + amount, debt)


## What may still be borrowed before the credit limit.
func availableCredit() -> int:
	return maxi(CreditLimit - debt, 0)


## Draws up to amount on the credit line, never past the limit. Returns what it took.
func borrow(amount: int) -> int:
	var taken: int = clampi(amount, 0, availableCredit())
	_write(cash + taken, debt + taken)
	return taken


## Pays back up to amount, never more than is owed or than the cash in hand.
## Returns what it paid.
func repay(amount: int) -> int:
	var paid: int = clampi(amount, 0, mini(debt, cash))
	_write(cash - paid, debt - paid)
	return paid


## The monthly bill. Paid from cash when the cash covers it; otherwise the cash
## goes to zero and the shortfall, plus ShortfallFee of it, is borrowed
## automatically, past the credit limit if need be.
func charge(amount: int) -> void:
	if (amount <= cash):
		_write(cash - amount, debt)
		return
	var shortfall: int = amount - cash
	var fee: int = roundi(float(shortfall) * ShortfallFee)
	_write(0, debt + shortfall + fee)
	AutoBorrowed.emit(shortfall, fee)


## A month's interest on what is owed, whole dollars.
func interest() -> int:
	return roundi(float(debt) * MonthlyInterestRate)


## Sets the cash directly, for the console and tests. Never negative.
func setCash(amount: int) -> void:
	_write(maxi(amount, 0), debt)


## Sets the debt directly, for the console and tests. Never negative.
func setDebt(amount: int) -> void:
	_write(cash, maxi(amount, 0))


# The one place cash and debt are written, so every change is announced.
# Not `_set`: that name is Object's property-setting virtual.
func _write(newCash: int, newDebt: int) -> void:
	cash = newCash
	debt = newDebt
	MoneyChanged.emit()


func toDict() -> Dictionary:
	return {"cash": cash, "debt": debt}


## Null when data is missing a key.
static func fromDict(data: Dictionary) -> Finances:
	if (not Variants.hasKeys(data, SavedKeys, "Finances")):
		return null
	var finances: Finances = Finances.new()
	finances._write(Variants.toInt(data["cash"]), Variants.toInt(data["debt"]))
	return finances
