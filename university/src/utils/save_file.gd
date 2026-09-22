class_name SaveFile
## A saved game on disk: one dictionary written as JSON text. Floats are
## written at full precision, so what is read back is bit-identical to what was
## saved and a loaded game plays out exactly as the saved one would have. The
## only file I/O a save goes through; state classes never touch files.

const Indent: String = "\t"
const SortKeys: bool = true
const FullPrecision: bool = true
const NotASaveError: String = "SaveFile: '%s' does not hold a saved game."
const WriteError: String = "SaveFile: could not write '%s' (error %d)."
const ReadError: String = "SaveFile: could not open '%s' (error %d)."


static func encode(data: Dictionary) -> String:
	return JSON.stringify(data, Indent, SortKeys, FullPrecision)


## The dictionary the text holds, or null when it holds anything else.
static func decode(text: String) -> Variant:
	var parsed: Variant = JSON.parse_string(text)
	return parsed if (parsed is Dictionary) else null


static func write(path: String, data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if (file == null):
		push_error(WriteError % [path, FileAccess.get_open_error()])
		return false
	file.store_string(encode(data))
	file.close()
	return true


## The dictionary saved at path, or null when there is no file there. A file
## that is there but is not a save is reported, and also gives null.
static func read(path: String) -> Variant:
	if (not FileAccess.file_exists(path)):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if (file == null):
		push_error(ReadError % [path, FileAccess.get_open_error()])
		return null
	var data: Variant = decode(file.get_as_text())
	if (data == null):
		push_error(NotASaveError % path)
	return data
