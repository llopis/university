class_name MeterBar
extends Control
## A thin progress bar with marks, drawn: the dining load against recommended
## and limit, and the semester's progress. Colours come from the theme's
## MeterBar type.

const ThemeType: StringName = &"MeterBar"
const MarkWidth: float = 2.0
const MarkOverhang: float = 3.0
const NoLimit: float = -1.0
const ToneColors: Array[StringName] = [&"fill", &"good", &"warn", &"bad", &"fill"]

var _fraction: float = 0.0
var _tone: UiTone.Tone = UiTone.Tone.Normal
var _marks: Array[float] = []
var _limit: float = NoLimit


func setValue(fraction: float, tone: UiTone.Tone, marks: Array[float], limit: float) -> void:
	_fraction = clampf(fraction, 0.0, 1.0)
	_tone = tone
	_marks = marks.duplicate()
	_limit = limit
	queue_redraw()


func _draw() -> void:
	var radius: float = size.y / 2.0
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = get_theme_color(&"track", ThemeType)
	track.set_corner_radius_all(roundi(radius))
	draw_style_box(track, Rect2(Vector2.ZERO, size))
	if (_fraction > 0.0):
		var fill: StyleBoxFlat = StyleBoxFlat.new()
		fill.bg_color = get_theme_color(ToneColors[_tone], ThemeType)
		fill.set_corner_radius_all(roundi(radius))
		draw_style_box(fill, Rect2(Vector2.ZERO, Vector2(size.x * _fraction, size.y)))
	for mark: float in _marks:
		_drawMark(mark, get_theme_color(&"mark", ThemeType))
	if (_limit >= 0.0):
		_drawMark(_limit, get_theme_color(&"limit", ThemeType))


func _drawMark(at: float, color: Color) -> void:
	var x: float = clampf(at, 0.0, 1.0) * size.x - MarkWidth / 2.0
	draw_rect(Rect2(x, -MarkOverhang, MarkWidth, size.y + MarkOverhang * 2.0), color)
