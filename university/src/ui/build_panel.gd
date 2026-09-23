class_name BuildPanel
extends PanelContainer
## The build catalogue: categories from the Sheet's category column in the
## order they first appear, each with its count, and a card per type showing
## its cost, what it adds, its upkeep and its footprint. A card is greyed out
## while the campus cannot afford it and highlighted while armed. Choosing one
## only announces it; the controller arms it. Cards are made in code because
## how many there are is data.

signal BuildingChosen(info: BuildingInfo)

const CountFormat: String = "%d"
const FxFormat: String = "%s · upkeep %s / mo · %s"
const FxNoCapacityFormat: String = "upkeep %s / mo · %s"
const InfoFormat: String = "%s · %s · cash %s"
const WarnFormat: String = "borrow first, or wait for the %s fees"
const OpensFormat: String = "Placed now → under construction until %s starts"
const ChooseText: String = "Choose a building to place it."
const DisabledAlpha: float = 0.45
const CardHeight: float = 88.0

# The Card style's own content margins, matched here because a Button lays out
# no children by itself: this VBox is positioned by hand inside it.
const CardMarginX: float = 12.0
const CardMarginY: float = 10.0
# How far the category count label sits from its button's right edge.
const CategoryCountMargin: float = 8.0

@onready var categoryList: VBoxContainer = %CategoryList
@onready var cards: GridContainer = %Cards
@onready var footInfo: Label = %FootInfo
@onready var footWarn: Label = %FootWarn
@onready var footOpens: Label = %FootOpens

var university: University

var _db: BuildingInfoDB
var _categoryButtons: Dictionary[String, Button]
var _cards: Dictionary[BuildingInfo, Button]
var _category: String = ""
var _armed: BuildingInfo
var _hovered: BuildingInfo


func populate(db: BuildingInfoDB) -> void:
	_db = db
	for category: String in db.categories():
		_addCategoryButton(category)
	for info: BuildingInfo in db.all:
		_addCard(info)
	var categories: Array[String] = db.categories()
	if (not categories.is_empty()):
		showCategory(categories[0])


func showCategory(category: String) -> void:
	_category = category
	for candidate: String in _categoryButtons:
		_categoryButtons[candidate].set_pressed_no_signal(candidate == category)
	for info: BuildingInfo in _cards:
		_cards[info].visible = (info.category == category)


## Greys out what cannot be paid for. The rule is the campus's, not the panel's.
func showAffordable(campus: Campus) -> void:
	for info: BuildingInfo in _cards:
		var card: Button = _cards[info]
		var affordable: bool = campus.canAfford(info)
		card.disabled = not affordable
		card.modulate.a = 1.0 if (affordable) else DisabledAlpha


## Shows which card is armed. Called on every tool change, so a press that
## toggled a card the wrong way is put right here.
func showTool(armed: BuildController.Tool, info: BuildingInfo) -> void:
	_armed = info if (armed == BuildController.Tool.Place) else null
	for entry: BuildingInfo in _cards:
		_cards[entry].set_pressed_no_signal(entry == _armed)


func _process(_dt: float) -> void:
	if (not visible or university == null):
		return
	var shown: BuildingInfo = _hovered if (_hovered != null) else _armed
	if (shown == null):
		footInfo.text = ChooseText
		footWarn.visible = false
		footOpens.visible = false
		return
	footInfo.text = InfoFormat % [shown.name, MoneyFormat.short(shown.cost), MoneyFormat.short(university.finances.cash)]
	var nextStart: int = university.nextSemesterStart()
	footWarn.visible = not university.campus.canAfford(shown)
	if (footWarn.visible):
		footWarn.text = WarnFormat % GameCalendar.PeriodNames[GameCalendar.period(nextStart)].to_lower()
	footOpens.visible = true
	footOpens.text = OpensFormat % GameCalendar.periodLabel(nextStart)


func _addCategoryButton(category: String) -> void:
	var button: Button = Button.new()
	button.theme_type_variation = &"CategoryButton"
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = category
	button.pressed.connect(showCategory.bind(category))
	categoryList.add_child(button)

	var count: Label = Label.new()
	count.theme_type_variation = &"Caption"
	count.text = CountFormat % _db.inCategory(category).size()
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.anchor_left = 1.0
	count.anchor_top = 0.5
	count.anchor_right = 1.0
	count.anchor_bottom = 0.5
	count.offset_right = -CategoryCountMargin
	count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count.grow_vertical = Control.GROW_DIRECTION_BOTH
	button.add_child(count)

	_categoryButtons[category] = button


func _addCard(info: BuildingInfo) -> void:
	var card: Button = Button.new()
	card.theme_type_variation = &"Card"
	card.toggle_mode = true
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size.y = CardHeight
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.pressed.connect(func() -> void: BuildingChosen.emit(info))
	card.mouse_entered.connect(func() -> void: _hovered = info)
	card.mouse_exited.connect(func() -> void: _hovered = null)

	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = CardMarginX
	box.offset_top = CardMarginY
	box.offset_right = -CardMarginX
	box.offset_bottom = -CardMarginY
	card.add_child(box)

	var head: HBoxContainer = HBoxContainer.new()
	box.add_child(head)
	var title: Label = Label.new()
	title.theme_type_variation = &"Heading"
	title.uppercase = true
	title.text = info.name
	head.add_child(title)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var cost: Label = Label.new()
	cost.theme_type_variation = &"Body"
	cost.text = MoneyFormat.short(info.cost)
	head.add_child(cost)

	var fx: Label = Label.new()
	fx.theme_type_variation = &"Caption"
	fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var adds: String = BuildingText.adds(info)
	fx.text = (FxFormat % [adds, MoneyFormat.short(info.upkeep), BuildingText.footprint(info)]) if (adds != "") \
		else (FxNoCapacityFormat % [MoneyFormat.short(info.upkeep), BuildingText.footprint(info)])
	box.add_child(fx)

	cards.add_child(card)
	_cards[info] = card
