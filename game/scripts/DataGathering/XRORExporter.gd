extends Node
class_name XRORExporter

@export var session_data: SessionData
@export var player_telemetry: PlayerTelemetryData

func export_session(file_name: String = "") -> void:

	if session_data == null:
		push_error("SessionData not assigned.")
		return

	if player_telemetry == null:
		push_error("PlayerTelemetryData not assigned.")
		return

	var xror := session_data.get_session()

	# PlayerTelemetry stores XROR frames
	xror["frames"] = player_telemetry.frames

	# SaberTelemetry is a global singleton (Autoload)
	xror["events"] = SaberTelemetryScript.events

	if file_name.is_empty():
		file_name = "session_%d.json" % Time.get_unix_time_from_system()

	var path := "user://" + file_name

	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		push_error("Could not create " + path)
		return

	file.store_string(JSON.stringify(xror, "\t"))
	file.close()
	
	var absolute_path := ProjectSettings.globalize_path(path)

	SupabaseUploader.upload_file(absolute_path)

	print("--------------------------------")
	print("XROR exported successfully!")
	print("Saved to: ", path)
	print("Frames: ", player_telemetry.frames.size())
	print("Events: ", SaberTelemetryScript.events.size())
