class_name DiningLoadLine
extends HBoxContainer
## The dining load as a bar and a percentage: the fill ends at the hard limit,
## the mark is the recommended load, and the tone says crowded or can't eat.
## The Housing dropdown and the dining hall's pane both show it.

const LoadNormal: String = "%s"
const LoadCrowded: String = "%s · crowded"
const LoadUnfed: String = "%s · can't eat"
# The red limit sits at the bar's end: the fill is scaled to the hard limit.
const LimitAtEnd: float = 1.0

@onready var bar: MeterBar = %Bar
@onready var valueLabel: Label = %Value


## The one tone the dining load reads in, from University.problems().
static func toneFor(university: University) -> UiTone.Tone:
	if (university.hasProblem(Problem.Kind.DiningUnfed)):
		return UiTone.Tone.Bad
	if (university.hasProblem(Problem.Kind.DiningCrowded)):
		return UiTone.Tone.Warn
	return UiTone.Tone.Normal


func display(university: University) -> void:
	var tone: UiTone.Tone = toneFor(university)
	var diningLoad: float = university.diningLoad()
	var marks: Array[float] = [UniversityRules.RecommendedLoad / UniversityRules.DiningHardLimit]
	bar.setValue(diningLoad / UniversityRules.DiningHardLimit, tone, marks, LimitAtEnd)
	var valueFormat: String = LoadNormal
	if (tone == UiTone.Tone.Bad):
		valueFormat = LoadUnfed
	elif (tone == UiTone.Tone.Warn):
		valueFormat = LoadCrowded
	valueLabel.text = valueFormat % NumberFormat.percent(diningLoad)
	valueLabel.theme_type_variation = UiTone.variation(InfoRow.ValueBase, tone)
