extends Node
class_name SessionData

var session: Dictionary = {}

var _session_id: String = ""

func _ready() -> void:
	_session_id = _generate_uuid()   # persists for the whole app run
	start_session()
	

func new_recording_id() -> void:
	session["$id"] = _generate_uuid()

func start_session() -> void:
	session = {
		"$id": _generate_uuid(),
		"session_id": _session_id, # Ignorado y dropped en el XROR por ahora, puede ser util a futuro.
		"info": {
			"name": "Open Saber Session",
			"timestamp": Time.get_unix_time_from_system(),
			"hardware": {
				"devices": [
					# TODO: Checkear convenciones a utilizar.
					{
						"name": "XR Headset",
						"type": "HMD",
						"joint": "HEAD",
						"axes": ["x", "y", "z", "i", "j", "k", "1"]
					},
					{
						"name": "Left Controller",
						"type": "CONTROLLER",
						"joint": "HAND_LEFT",
						"axes": ["x", "y", "z", "i", "j", "k", "1"]
					},
					{
						"name": "Right Controller",
						"type": "CONTROLLER",
						"joint": "HAND_RIGHT",
						"axes": ["x", "y", "z", "i", "j", "k", "1"]
					}
				]
			},
			"software": {
				"api": "OpenXR",
				"runtime": "",
				"app": {
					"id": "opensaber",
					"name": "Open Saber",
					"version": str(ProjectSettings.get_setting("application/config/version")),
					"extensions": []
				},
				"environment": {
					"id": "",
					"name": ""
				},
				"activity": {
					"id": "",
					"name": ""
				}
			},
			"user": {
				"id": "",
				"name": ""
			}
		},
	}
	print("Session metadata skeleton created.")

# Called by the game when a map starts, to fill in map-dependent fields.
func set_activity_from_map(map_info: MapInfo, diff: DifficultyInfo) -> void:
	@warning_ignore("unsafe_cast")
	var sw := session["info"]["software"] as Dictionary
	sw["environment"] = {
		"id": "",
		"name": map_info.environment_name
	}
	var song_hash := _read_or_compute_hash(map_info.filepath) # NUEVO CAMPO PARA XROR
	sw["activity"] = {
		"id": "",
		"songHash": song_hash, 
		"name": map_info.song_name,
		"mapper": map_info.level_author_name,
		"artist": map_info.song_author_name,
		"difficulty": diff.difficulty,
		"bpm": map_info.beats_per_minute,
		"njs": diff.note_jump_movement_speed,
	}
	print("Activity metadata set from map: ", map_info.song_name)

# Función para extraer el HASH almacenado en el dispositivo o computarlo desde el archivo
func _read_or_compute_hash(folder_path: String) -> String:
	var sidecar := folder_path.path_join("beatsaver_hash.txt")
	if FileAccess.file_exists(sidecar):
		var f := FileAccess.open(sidecar, FileAccess.READ)
		if f:
			var h := f.get_as_text().strip_edges()
			f.close()
			if not h.is_empty():
				return h
	# fallback for non-BeatSaver maps:
	return compute_map_hash(folder_path)   # the function from before

@warning_ignore("shadowed_variable_base_class")
#TODO: Incluir esta funcionalidad en el momento que se cree el auth.
func set_user(id: String, name: String = "") -> void:
	session["info"]["user"] = { "id": id, "name": name }

func get_session() -> Dictionary:
	return session

# Utils: A falta de UUIDs nativos en GDScript, se crea una función auxiliar para la generación de estos
func _generate_uuid() -> String:
	# Godot 4 has no built-in UUID; this is a simple RFC-4122-ish v4.
	var b := PackedByteArray()
	@warning_ignore("return_value_discarded")
	b.resize(16)
	for i in 16:
		b[i] = randi() % 256
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		h.substr(0, 8), h.substr(8, 4), h.substr(12, 4),
		h.substr(16, 4), h.substr(20, 12)
	]

# =============================================================================
# ======== FALL BACK FOR HASHING SONGS ========================================
# Computes the BeatSaver/BeatLeader-compatible map hash for a song folder.
# folder_path: the map's directory (e.g. info.filepath), must end with "/".
# Returns lowercase hex SHA-1, or "" on failure.
static func compute_map_hash(folder_path: String) -> String:
	var info_path := folder_path.path_join("info.dat")
	# Some maps use "Info.dat" capitalization — handle both.
	if not FileAccess.file_exists(info_path):
		info_path = folder_path.path_join("Info.dat")
	if not FileAccess.file_exists(info_path):
		push_error("compute_map_hash: no info.dat in " + folder_path)
		return ""

	var info_file := FileAccess.open(info_path, FileAccess.READ)
	if info_file == null:
		return ""
	var info_bytes := info_file.get_buffer(info_file.get_length())
	info_file.close()

	# Parse info.dat ONLY to discover the ordered list of diff filenames.
	# The bytes we hash are the raw ones above, not this parse.
	var info_json: Variant = JSON.parse_string(info_bytes.get_string_from_utf8())
	if not info_json is Dictionary:
		push_error("compute_map_hash: info.dat not valid JSON")
		return ""
	var info_dict := info_json as Dictionary

	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	ctx.update(info_bytes)

	# Walk _difficultyBeatmapSets -> _difficultyBeatmaps in listed order,
	# appending each referenced beatmap file's raw bytes.
	var sets: Array = info_dict.get("_difficultyBeatmapSets", [])
	for s in sets:
		if not s is Dictionary: continue
		var beatmaps: Array = (s as Dictionary).get("_difficultyBeatmaps", [])
		for bm in beatmaps:
			if not bm is Dictionary: continue
			var fname := str((bm as Dictionary).get("_beatmapFilename", ""))
			if fname.is_empty(): continue
			var diff_path := folder_path.path_join(fname)
			if not FileAccess.file_exists(diff_path):
				push_error("compute_map_hash: missing diff file " + diff_path)
				return ""  # missing file => hash would be wrong; fail loudly
			var df := FileAccess.open(diff_path, FileAccess.READ)
			if df == null:
				return ""
			var diff_bytes := df.get_buffer(df.get_length())
			df.close()
			ctx.update(diff_bytes)

	return ctx.finish().hex_encode()
# ==============================================================================
