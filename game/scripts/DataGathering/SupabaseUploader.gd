extends Node
class_name SupabaseUploader

signal upload_finished(success: bool)

var supabase_url: String = ""
var anon_key: String = ""
var bucket: String = ""
var folder: String = ""

var http: HTTPRequest = null
var initialized := false
var uploading := false


func initialize() -> bool:

	if initialized:
		return true

	# -----------------------------
	# Hardcoded configuration
	# -----------------------------
	supabase_url = "https://mbotszxdxyiqadubpmek.supabase.co"

	anon_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ib3RzenhkeHlpcWFkdWJwbWVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU5NjY3OTIsImV4cCI6MjEwMTU0Mjc5Mn0.-b-4GqVC02Ky9pT56qBhMbI3JWlEbdi1HxVLo1g2hxc"

	bucket = "OpenSaberFiles"
	folder = "TestFolder"

	# -----------------------------
	# HTTPRequest
	# -----------------------------
	http = HTTPRequest.new()
	add_child(http)
	http.timeout = 30
	http.request_completed.connect(_on_request_completed)

	initialized = true

	print("--------------------------------")
	print("Supabase uploader initialized.")
	print("URL: ", supabase_url)
	print("Bucket: ", bucket)
	print("Folder: ", folder)

	return true

	print("--------------------------------")
	print("Supabase uploader initialized.")
	print("URL: ", supabase_url)
	print("Bucket: ", bucket)
	print("Folder: ", folder)

	return true


func _ready() -> void:
	initialize()


func upload_file(file_path: String) -> void:

	if not initialize():
		upload_finished.emit(false)
		return

	if uploading:
		print("Upload already in progress. Skipping.")
		return

	if http == null or not is_instance_valid(http):
		push_error("HTTPRequest is invalid.")
		upload_finished.emit(false)
		return

	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		print("HTTP client busy. Skipping upload.")
		return

	if not FileAccess.file_exists(file_path):
		push_error("File does not exist: " + file_path)
		upload_finished.emit(false)
		return

	var file := FileAccess.open(file_path, FileAccess.READ)

	if file == null:
		push_error("Couldn't open file.")
		upload_finished.emit(false)
		return

	var bytes := file.get_buffer(file.get_length())
	file.close()

	var remote_path := folder.path_join(file_path.get_file())

	var url := "%s/storage/v1/object/%s/%s" % [
		supabase_url,
		bucket,
		remote_path
	]

	var headers := PackedStringArray([
		"apikey: %s" % anon_key,
		"Authorization: Bearer %s" % anon_key,
		"Content-Type: application/json",
		"x-upsert: true"
	])

	print("--------------------------------")
	print("Uploading XROR...")
	print("Local file: ", file_path)
	print("Remote path: ", remote_path)
	print("URL: ", url)

	uploading = true

	var err := http.request_raw(
		url,
		headers,
		HTTPClient.METHOD_POST,
		bytes
	)

	if err != OK:
		uploading = false
		push_error("Failed to start HTTP request: %d" % err)
		upload_finished.emit(false)
	else:
		print("HTTPRequest started.")


func _on_request_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:

	uploading = false

	print("--------------------------------")
	print("Upload completed.")
	print("Result: ", result)
	print("HTTP Code: ", response_code)
	print("Response:")
	print(body.get_string_from_utf8())

	var success := (
		result == HTTPRequest.RESULT_SUCCESS
		and response_code >= 200
		and response_code < 300
	)

	if success:
		print("Supabase upload successful.")
	else:
		push_error("Supabase upload failed.")

	upload_finished.emit(success)
