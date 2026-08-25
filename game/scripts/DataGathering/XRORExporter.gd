extends Node
class_name XRORExporter

@export var session_data: SessionData
@export var player_telemetry: PlayerTelemetryData
@export var uploader: SupabaseUploader

@export var upload_interval: float = 30.0

var timer: Timer
var session_file_path: String = ""
var recording := false
var user_id := ""


func _ready() -> void:
	if uploader == null:
		push_error("SupabaseUploader not assigned.")

	timer = Timer.new()
	timer.wait_time = upload_interval
	timer.one_shot = false
	timer.autostart = false
	add_child(timer)
	timer.timeout.connect(_on_upload_timer_timeout)

	print("XROR Exporter initialized. Waiting for player login.")


func begin_recording(p_user_id: String, username: String, access_token: String = "") -> void:
	user_id = p_user_id

	if session_data:
		session_data.set_user(p_user_id, username)

	if player_telemetry:
		player_telemetry.clear_frames()
		player_telemetry.enabled = true

	SaberTelemetryScript.clear_events()

	if uploader:
		uploader.access_token = access_token
		uploader.user_folder = p_user_id

	session_file_path = create_session_file()
	if session_file_path.is_empty():
		push_error("Could not create XROR session file.")
		return

	recording = true
	timer.start()
	_on_upload_timer_timeout()

	print("--------------------------------")
	print("XROR recording started for user ", username, " (", p_user_id, ")")
	print("Session file: ", session_file_path)


func create_session_file() -> String:
	var file_name := "session_%s_%d.json" % [user_id, Time.get_unix_time_from_system()]
	var path := "user://" + file_name
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string("{}")
	file.close()
	return ProjectSettings.globalize_path(path)


func export_session() -> void:
	if not recording:
		return
	_on_upload_timer_timeout()


func _on_upload_timer_timeout() -> void:
	if not recording:
		return

	print("--------------------------------")
	print("Upload triggered.")

	var file_path := update_session_file()
	if file_path.is_empty():
		print("Export failed.")
		return

	if uploader == null:
		push_error("SupabaseUploader not assigned.")
		return

	uploader.upload_file(file_path)


func update_session_file() -> String:
	if session_data == null:
		push_error("SessionData not assigned.")
		return ""

	if player_telemetry == null:
		push_error("PlayerTelemetryData not assigned.")
		return ""

	if session_file_path.is_empty():
		push_error("Session file was never created.")
		return ""

	var xror := session_data.get_session()
	xror["frames"] = player_telemetry.frames
	xror["events"] = SaberTelemetryScript.events

	var local_path := ProjectSettings.globalize_path("user://")
	var relative_path := session_file_path.replace(local_path, "user://")

	var file := FileAccess.open(relative_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not update " + relative_path)
		return ""

	file.store_string(JSON.stringify(xror, "\t"))
	file.close()

	print("--------------------------------")
	print("XROR updated.")
	print("Frames: ", player_telemetry.frames.size())
	print("Events: ", SaberTelemetryScript.events.size())

	return session_file_path
