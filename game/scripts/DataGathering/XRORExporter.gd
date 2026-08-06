extends Node
class_name XRORExporter

@export var session_data: SessionData
@export var player_telemetry: PlayerTelemetryData
@export var uploader: SupabaseUploader

@export var upload_interval: float = 30.0

var timer: Timer
var session_file_path: String = ""


func _ready() -> void:

	if uploader == null:
		push_error("SupabaseUploader not assigned.")

	# Create XROR file once at game start
	session_file_path = create_session_file()

	if session_file_path.is_empty():
		push_error("Could not create XROR session file.")
		return

	timer = Timer.new()
	timer.wait_time = upload_interval
	timer.one_shot = false
	timer.autostart = true
	add_child(timer)

	timer.timeout.connect(_on_upload_timer_timeout)

	print("--------------------------------")
	print("XROR Exporter initialized.")
	print("Session file: ", session_file_path)
	print("Uploading every ", upload_interval, " seconds.")


func create_session_file() -> String:

	var file_name := "session_%d.json" % Time.get_unix_time_from_system()
	var path := "user://" + file_name

	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		return ""

	file.store_string("{}")
	file.close()

	return ProjectSettings.globalize_path(path)


func _on_upload_timer_timeout() -> void:

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


	# Convert absolute path back to user://
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
