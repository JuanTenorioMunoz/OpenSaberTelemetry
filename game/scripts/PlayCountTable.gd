extends Node
class_name PlayCountTable

# location to store the play counts on filesystem
const PLAY_COUNT_FILEPATH = "user://play_count.json"

# internal copy of the play count table
# restored from user file in _ready()
# {
#   "<song_key>" : {
#       "1" : 0,
#       "3" : 10
#   }
# }
var _pc_table: Dictionary = {}

func _ready() -> void:
	load_table()

# clears the whole play count table
func clear_table() -> void:
	_pc_table = {}

# removes a given map from the table, effectively resetting that map's counters
func remove_map(map_info: MapInfo) -> void:
	var song_key := map_info.get_key()

	@warning_ignore("return_value_discarded")
	_pc_table.erase(song_key)

	save_table()

# increments the map's play count by 1.
func increment_play_count(map_info: MapInfo, diff_rank: int) -> void:
	var song_key := map_info.get_key()

	var key_dict := Utils.get_dict(_pc_table, song_key, {})

	if not _pc_table.has(song_key):
		_pc_table[song_key] = key_dict

	var diff_str := str(diff_rank)

	if not key_dict.has(diff_str):
		key_dict[diff_str] = 0

	key_dict[diff_str] += 1

	save_table()

# return : the map's play count for the given difficulty
func get_play_count(map_info: MapInfo, diff_rank: int) -> int:
	var song_key := map_info.get_key()

	var key_dict := Utils.get_dict(_pc_table, song_key, {})

	if key_dict.is_empty():
		return 0

	var diff_str := str(diff_rank)

	if not key_dict.has(diff_str):
		return 0

	return int(Utils.get_float(key_dict, diff_str, 0))

# return : the map's total play count across all difficulties
func get_total_play_count(map_info: MapInfo) -> int:
	var song_key := map_info.get_key()

	var key_dict := Utils.get_dict(_pc_table, song_key, {})

	if key_dict.is_empty():
		return 0

	var total := 0

	for count in key_dict.values():
		total += count

	return total

# restores play count table from filesystem
func load_table() -> void:
	var file := FileAccess.open(PLAY_COUNT_FILEPATH, FileAccess.READ)

	if file == null:
		print("WARN: Failed to open %s (might not exist yet)" % PLAY_COUNT_FILEPATH)
		_pc_table = {}
		return

	var text := file.get_as_text()
	file.close()

	print("--------------------------------")
	print("Loading play count table...")
	print("File: ", PLAY_COUNT_FILEPATH)
	print("Contents:")
	print(text)
	print("--------------------------------")

	if text.strip_edges().is_empty():
		push_warning("play_count.json is empty.")
		_pc_table = {}
		return

	var parsed = JSON.parse_string(text)

	if parsed == null:
		push_error("JSON parse failed for " + PLAY_COUNT_FILEPATH)
		_pc_table = {}
		return

	if parsed is Dictionary:
		_pc_table = parsed
		print("Play count table loaded successfully.")
		print("Entries: ", _pc_table.size())
	else:
		push_error("play_count.json does not contain a Dictionary.")
		_pc_table = {}

# saves play count table to filesystem
func save_table() -> void:
	var file := FileAccess.open(PLAY_COUNT_FILEPATH, FileAccess.WRITE)

	if file:
		file.store_string(JSON.stringify(_pc_table, "   ", true))
		file.close()

		print("Play count table saved.")
		print("Entries: ", _pc_table.size())
	else:
		print("ERROR: Failed to open %s" % PLAY_COUNT_FILEPATH)
