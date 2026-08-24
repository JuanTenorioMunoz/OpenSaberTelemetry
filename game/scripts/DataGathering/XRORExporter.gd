extends Node
class_name XRORExporter

@export var session_data: SessionData
@export var player_telemetry: PlayerTelemetryData
@export var uploader: SupabaseUploader

# Checkpoint the in-memory buffer to local disk this often (seconds) for crash safety.
@export var checkpoint_interval: float = 60.0

var _checkpoint_timer: Timer
var _current_recording_id: String = ""
var _current_scratch_path: String = ""   # user:// path of the in-progress song
var _recording_active: bool = false

func _ready() -> void:
	if uploader == null:
		push_error("SupabaseUploader not assigned.")
	if session_data == null:
		push_error("SessionData not assigned.")
	if player_telemetry == null:
		push_error("PlayerTelemetryData not assigned.")

	# Checkpoint timer — only does anything while a song is active.
	_checkpoint_timer = Timer.new()
	_checkpoint_timer.wait_time = checkpoint_interval
	_checkpoint_timer.one_shot = false
	_checkpoint_timer.autostart = false
	add_child(_checkpoint_timer)
	_checkpoint_timer.timeout.connect(_on_checkpoint)

	# On launch, sweep for orphaned scratch files from a crashed prior run.
	_recover_orphaned_recordings()

	print("XROR Exporter initialized (per-song mode).")

# ---- Called by the game at song start ----
func begin_recording() -> void:
	# Fresh buffers for this song.
	session_data.new_recording_id()
	player_telemetry.frames.clear()
	SaberTelemetryScript.events.clear()

	# The recording id is the per-song $id already minted in SessionData's metadata.
	var session := session_data.get_session()
	_current_recording_id = str(session.get("$id", _fallback_id()))
	_current_scratch_path = "user://recording_%s.json" % _current_recording_id
	_recording_active = true
	_checkpoint_timer.start()
	print("Recording started: ", _current_recording_id)

# ---- Called by the game at song end (normal completion) ----
func end_recording() -> void:
	if not _recording_active:
		return
	_checkpoint_timer.stop()
	_recording_active = false

	var path := _write_session_file(_current_scratch_path)
	if path.is_empty():
		push_error("Failed to write final session file.")
		return

	# Upload; on confirmed success we delete the scratch file (see _on_upload_done).
	_upload_and_cleanup(path)

# ---- Periodic local checkpoint (no network) ----
func _on_checkpoint() -> void:
	if not _recording_active:
		return
	_write_session_file(_current_scratch_path)
	print("Checkpoint: %d frames, %d events" % [
		player_telemetry.frames.size(), SaberTelemetryScript.events.size()])

# ---- Build the full nested XROR-shaped JSON and write it to `user_path` ----
func _write_session_file(user_path: String) -> String:
	if session_data == null or player_telemetry == null:
		return ""

	# Start from the metadata skeleton (already nested by SessionData / Phase 7).
	var xror := session_data.get_session().duplicate(true)

	# Flatten frames into XROR rows: [time, head(7), left(7), right(7)].
	# ORDER MUST MATCH SessionData.devices: headset, left_controller, right_controller,
	# each with axes [x,y,z,i,j,k,1]. If that device order changes, change this too.
	var flat_frames: Array = []
	for f in player_telemetry.frames:
		flat_frames.append(_flatten_frame(f))
	xror["frames"] = flat_frames

	# Events stay a flat list; the Python worker groups them by type.
	xror["events"] = SaberTelemetryScript.events

	var file := FileAccess.open(user_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open scratch file: " + user_path)
		return ""
	file.store_string(JSON.stringify(xror))
	file.close()
	return user_path

func _flatten_frame(f: Dictionary) -> Array:
	var row: Array = [f["time"]]
	for key in ["headset", "left_controller", "right_controller"]:
		var dev := f[key] as Dictionary
		var pos := dev["position"] as Array   # [x,y,z]
		var rot := dev["rotation"] as Array   # [x,y,z,w] -> axes i,j,k,1
		row.append(pos[0]); row.append(pos[1]); row.append(pos[2])
		row.append(rot[0]); row.append(rot[1]); row.append(rot[2]); row.append(rot[3])
	return row

# ---- Upload, and delete the scratch file only on confirmed success ----
func _upload_and_cleanup(user_path: String) -> void:
	if uploader == null:
		push_error("No uploader; leaving scratch file for later: " + user_path)
		return
	var abs_path := ProjectSettings.globalize_path(user_path)

	# One-shot connection so we can clean up after this specific upload.
	var on_done := func(success: bool) -> void:
		if success:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(user_path))
			print("Uploaded and cleaned up: ", user_path)
		else:
			push_error("Upload failed; scratch file kept for retry: " + user_path)
	if not uploader.upload_finished.is_connected(on_done):
		uploader.upload_finished.connect(on_done, CONNECT_ONE_SHOT)

	uploader.upload_file(abs_path)

# ---- On launch, upload any scratch files left by a crashed run ----
func _recover_orphaned_recordings() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("recording_") and name.ends_with(".json"):
			var user_path := "user://" + name
			print("Recovering orphaned recording: ", user_path)
			_upload_and_cleanup(user_path)
		name = dir.get_next()
	dir.list_dir_end()

func _fallback_id() -> String:
	return "rec_%d" % Time.get_ticks_usec() 
