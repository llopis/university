class_name CsvLoader


static func load_csv(path: String) -> Array[Dictionary]:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	# Normalize CRLF/CR line endings so the final column of each row doesn't keep
	# a trailing "\r" (which would corrupt header keys and values).
	var text: String = file.get_as_text().replace("\r\n", "\n").replace("\r", "\n")
	var lines: PackedStringArray = text.strip_edges().split("\n")
	if lines.size() < 2:
		return []
	var headers: Array[String] = _parse_row(lines[0])
	var result: Array[Dictionary] = []
	for i: int in range(1, lines.size()):
		var values: Array[String] = _parse_row(lines[i])
		var row: Dictionary = {}
		for j: int in range(mini(headers.size(), values.size())):
			row[headers[j]] = _coerce(values[j])
		result.append(row)
	return result


static func _parse_row(line: String) -> Array[String]:
	var fields: Array[String] = []
	var current: String = ""
	var in_quotes: bool = false
	var i: int = 0
	while i < line.length():
		var c: String = line[i]
		if in_quotes:
			if c == "\"":
				if i + 1 < line.length() and line[i + 1] == "\"":
					current += "\""
					i += 1
				else:
					in_quotes = false
			else:
				current += c
		else:
			if c == "\"":
				in_quotes = true
			elif c == ",":
				fields.append(current)
				current = ""
			else:
				current += c
		i += 1
	fields.append(current)
	return fields


static func _coerce(value: String) -> Variant:
	if value == "TRUE":
		return true
	if value == "FALSE":
		return false
	if value.is_valid_int():
		return value.to_int()
	if value.is_valid_float():
		return value.to_float()
	return value
