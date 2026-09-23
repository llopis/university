#!/usr/bin/env python3

# Applies the UI palette to the UI's theme and scenes. The palette,
# university/src/ui/ui_palette.tres, is the ONE place a UI colour is chosen:
# every colour in the UI files is one of its entries or a tinted copy of one.
# It is a Theme resource holding nothing but the Palette type's colours, so
# Godot's Inspector edits them with a colour picker. Change a colour there, or
# add one, save it, and run:
#     python3 bin/apply_palette.py            rewrite the UI files to match
#     python3 bin/apply_palette.py --check    change nothing; exit 1 if anything is out of step
#
# Notes:
# - Godot has no colour variables: every StyleBox and theme colour holds its
#   own Color(...) literal, so this script finds the literals by value. The
#   theme's Palette/colors block records the value each entry's literals hold
#   now; a changed entry is found under its recorded value and rewritten to
#   its new one, block included. The script writes that block: never edit it
#   by hand, in a text editor or in Godot — ui_theme.tres's Palette type is
#   the copy, ui_palette.tres's the one to change.
# - A literal is an entry exactly (all four channels), or a tinted copy of one:
#   the entry's RGB at an alpha of its own (the 18% pill backgrounds, the
#   deeper shadows and the dim). A tinted copy takes the new RGB and keeps its
#   alpha. It is only recognised while no other entry shares that RGB — line,
#   line2 and mark are all white, so a white literal must be one of them exactly.
# - A fully transparent literal and opaque white (a base for self_modulate) are
#   not colours, and are left alone. Anything else is reported as outside the
#   palette: use an entry, or add one.
# - Every UI scene lives under UiDirs, and a new one there is picked up by
#   itself. A UI scene or resource anywhere else must be added to UiDirs.
#   Scripts are only checked, never rewritten: UI code reads a colour with
#   get_theme_color(name, &"Palette").

import argparse
import os
import re

Root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
PalettePath = 'university/src/ui/ui_palette.tres'
ThemePath = 'university/src/ui/ui_theme.tres'
UiDirs = ['university/src/ui']
RewrittenExtensions = ('.tres', '.tscn')
CheckedExtensions = ('.gd',)

# Past half an 8-bit step: this script writes 3 decimals, Godot full float
# precision, and the two must still read as the same colour.
Tolerance = 0.003
Rgb = range(3)
Rgba = range(4)
Transparent = 0.0
White = (1.0, 1.0, 1.0, 1.0)

PaletteLine = re.compile(r'^Palette/colors/(\w+) = (Color\([^)]*\))$')
ColorLiteral = re.compile(
	r'Color\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)')


def toHex(color):
	digits = ''.join('%02x' % round(c * 255) for c in color)
	return '#' + (digits[:6] if digits.endswith('ff') else digits)


def parseLiteral(match):
	alpha = match.group(4)
	return tuple([float(match.group(i)) for i in range(1, 4)] + [float(alpha) if alpha is not None else 1.0])


def formatChannel(value):
	rounded = round(value, 3)
	if rounded == 0:
		return '0'
	if rounded == 1:
		return '1'
	return '%.3f' % rounded


def formatColor(color):
	return 'Color(%s)' % ', '.join(formatChannel(c) for c in color)


def near(a, b, channels):
	return all(abs(a[i] - b[i]) <= Tolerance for i in channels)


def classify(color, palette):
	# ('exact' | 'tinted', entry name), ('free', None) for a literal that is not
	# a colour, or ('outside', None).
	if color[3] <= Transparent + Tolerance or near(color, White, Rgba):
		return ('free', None)
	for name, value in palette.items():
		if near(color, value, Rgba):
			return ('exact', name)
	tinted = [name for name, value in palette.items() if near(color, value, Rgb)]
	if len(tinted) == 1:
		return ('tinted', tinted[0])
	return ('outside', None)


def readPalette():
	with open(os.path.join(Root, PalettePath)) as f:
		palette = readColors(f.read())
	names = list(palette)
	for i, first in enumerate(names):
		for second in names[i + 1:]:
			if near(palette[first], palette[second], Rgba):
				raise SystemExit('ERROR: %s and %s are the same colour, and could never be told apart '
					'again. Use one entry for both.' % (first, second))
	return palette


def readColors(text):
	# A Palette block, from the palette or from the theme, where it records the
	# value each entry's literals hold now.
	colors = {}
	for line in text.split('\n'):
		match = PaletteLine.match(line)
		if match:
			colors[match.group(1)] = parseLiteral(ColorLiteral.match(match.group(2)))
	return colors


def rewriteLiteral(match, recorded, palette, counts):
	kind, name = classify(parseLiteral(match), recorded)
	if kind not in ('exact', 'tinted') or near(recorded[name], palette[name], Rgba):
		return match.group(0)
	counts[name][kind] += 1
	if kind == 'exact':
		return formatColor(palette[name])
	return 'Color(%s, %s)' % (', '.join(formatChannel(c) for c in palette[name][:3]), match.group(4))


def rewriteBlock(lines, recorded, palette):
	# The block regenerated in palette order; an unchanged entry keeps its line.
	indices = [i for i, line in enumerate(lines) if PaletteLine.match(line)]
	if indices != list(range(indices[0], indices[-1] + 1)):
		raise SystemExit('ERROR: the Palette/colors lines in %s must stay together.' % ThemePath)
	kept = {PaletteLine.match(lines[i]).group(1): lines[i] for i in indices}
	block = [kept[name] if name in recorded and near(recorded[name], value, Rgba)
		else 'Palette/colors/%s = %s' % (name, formatColor(value)) for name, value in palette.items()]
	return lines[:indices[0]] + block + lines[indices[-1] + 1:]


def rewrite(path, text, recorded, palette, counts):
	lines = [line if PaletteLine.match(line)
		else ColorLiteral.sub(lambda m: rewriteLiteral(m, recorded, palette, counts), line)
		for line in text.split('\n')]
	if path == ThemePath:
		lines = rewriteBlock(lines, recorded, palette)
	return '\n'.join(lines)


def uiFiles():
	paths = []
	for uiDir in UiDirs:
		for folder, _, names in os.walk(os.path.join(Root, uiDir)):
			paths += [os.path.relpath(os.path.join(folder, name), Root) for name in names
				if name.endswith(RewrittenExtensions + CheckedExtensions)]
	return sorted(path for path in paths if path != PalettePath)


def main():
	parser = argparse.ArgumentParser(description='Apply ui_palette.tres to the UI files.')
	parser.add_argument('--check', action='store_true', help='change nothing; exit 1 if anything is out of step')
	check = parser.parse_args().check

	palette = readPalette()
	originals = {}
	for path in uiFiles():
		with open(os.path.join(Root, path)) as f:
			originals[path] = f.read()
	recorded = readColors(originals[ThemePath])
	for name in recorded:
		if name not in palette:
			raise SystemExit('ERROR: %s is in the theme\'s Palette block but not in %s. Put it back, '
				'and move its colours to another entry before removing it.' % (name, PalettePath))

	counts = {name: {'exact': 0, 'tinted': 0} for name in palette}
	rewritten = {path: rewrite(path, text, recorded, palette, counts) if path.endswith(RewrittenExtensions) else text
		for path, text in originals.items()}
	changed = [path for path in rewritten if rewritten[path] != originals[path]]

	for name, value in palette.items():
		if name not in recorded:
			print('%-10s new, %s' % (name, toHex(value)))
		elif not near(recorded[name], value, Rgba):
			print('%-10s %s -> %s: %d exact, %d tinted' % (name, toHex(recorded[name]), toHex(value),
				counts[name]['exact'], counts[name]['tinted']))

	outside = []
	for path, text in rewritten.items():
		for number, line in enumerate(text.split('\n'), 1):
			if PaletteLine.match(line):
				continue
			for match in ColorLiteral.finditer(line):
				if classify(parseLiteral(match), palette)[0] == 'outside':
					outside.append('  %s:%d  %s' % (path, number, match.group(0)))
	if outside:
		print('Outside the palette (use an entry, or add one):')
		print('\n'.join(outside))

	if check:
		if changed:
			print('Out of step with the palette: %s' % ', '.join(changed))
	else:
		for path in changed:
			with open(os.path.join(Root, path), 'w') as f:
				f.write(rewritten[path])
			print('wrote %s' % path)
	if not changed and not outside:
		print('The UI files match the palette.')
	raise SystemExit(1 if outside or (check and changed) else 0)


if __name__ == '__main__':
	main()
