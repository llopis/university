#!/usr/bin/env python3

# Exports the University Google Sheet's data tabs to the committed data files
# the game loads. The Sheet is the SOURCE OF TRUTH; these .txt files are only
# its export — never hand-edit them (see CLAUDE.md). Run:
#     python3 bin/GetDataFromGoogleSheets.py
#
# Notes:
# - Written as .txt, NOT .csv: Godot auto-imports *.csv as a Translation resource,
#   which relocates the file and breaks FileAccess reads (see src/utils/csv_loader.gd).
# - Uses the standard /export CSV endpoint (keyed by numeric gid), which returns the
#   sheet's raw cell values as clean, unquoted CSV. The sheet must be shared
#   "anyone with the link can view"; a private sheet returns an HTML login page,
#   which this script detects and aborts on rather than writing garbage over the data.

import os
import urllib.request

# "University" spreadsheet:
# https://docs.google.com/spreadsheets/d/1SrPqAyHSve_LWaLmMrgl6orvEwqlx_luDhub1MSIFio/
KEY = '1SrPqAyHSve_LWaLmMrgl6orvEwqlx_luDhub1MSIFio'

# (tab gid, output path relative to this script's directory).
EXPORTS = [
	(948960558, '../university/data/buildings.txt'),
]


def sheetCsvUrl(key, gid):
	return 'https://docs.google.com/spreadsheets/d/%s/export?format=csv&gid=%s' % (key, gid)


def fetch(url):
	with urllib.request.urlopen(urllib.request.Request(url)) as response:
		return response.read().decode('utf-8')


def exportSheet(key, gid, filename):
	data = fetch(sheetCsvUrl(key, gid))
	if '<html' in data[:200].lower():
		raise SystemExit(
			"ERROR: got an HTML page, not CSV, for gid %s — the sheet must be shared "
			"'anyone with the link can view'." % gid)
	# Normalize CRLF -> LF so the committed file stays LF-only, and end with one newline.
	data = data.replace('\r\n', '\n').replace('\r', '\n').rstrip('\n') + '\n'
	path = os.path.join(os.path.dirname(__file__), filename)
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with open(path, 'w') as f:
		f.write(data)
	print('wrote %s (%d bytes)' % (filename, len(data)))


if __name__ == '__main__':
	for gid, filename in EXPORTS:
		exportSheet(KEY, gid, filename)
