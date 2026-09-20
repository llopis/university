#!/usr/bin/env python3

import urllib.request
import os

def importUrl(url):
	req = urllib.request.Request(url)
	with urllib.request.urlopen(req) as response:
	   return response.read().decode('utf-8')


def getSheetUrl(key, sheet):
	return 'https://docs.google.com/spreadsheets/d/' + key + '/gviz/tq?tqx=out:csv&sheet=' + sheet

def importSheet(key, sheet):
	return 

def exportSheet(key, sheet, filename):
	dirname = os.path.dirname(__file__)

	data = importUrl(getSheetUrl(key, sheet))
	fullFilename = os.path.join(dirname, filename)
	csvFile = open(fullFilename, 'w')
	for row in data:
		csvFile.write(row)
	csvFile.close()



key = '1IMrkKhjrQcnDG2YaFxPoWDmyuVW6GIigssRY2jHvQKU'
if __name__ == '__main__':
	exportSheet(key, 'Buildings', '../terraform/data/buildings.csv')
	exportSheet(key, 'Products', '../terraform/data/products.csv')
	exportSheet(key, 'OreDeposits', '../terraform/data/deposits.csv')
