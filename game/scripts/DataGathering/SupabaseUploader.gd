extends Node
class_name SupabaseUploaderScript

var supabase_url: String
var anon_key: String
var bucket: String
var folder: String

var http: HTTPRequest

func _ready() -> void:
	var cfg := ConfigFile.new()

	if cfg.load("res://config/config.cfg") != OK:
		push_error("Couldn't load config.cfg")
		return

	supabase_url = str(cfg.get_value("supabase", "url"))
	anon_key = str(cfg.get_value("supabase", "anon_key"))
	bucket = str(cfg.get_value("supabase", "bucket"))
	folder = str(cfg.get_value("supabase", "folder"))

	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)

	print("Supabase uploader initialized.")
	print("URL: ", supabase_url)
	print("Bucket: ", bucket)
	print("Folder: ", folder)


func upload_file(file_path: String) -> void:

	if not FileAccess.file_exists(file_path):
		push_error("File does not exist: " + file_path)
		return

	var file := FileAccess.open(file_path, FileAccess.READ)

	if file == null:
		push_error("Couldn't open file.")
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

	var err := http.request_raw(
		url,
		headers,
		HTTPClient.METHOD_POST,
		bytes
	)

	if err != OK:
		push_error("HTTPRequest failed: %d" % err)


func _on_request_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:

	print("--------------------------------")
	print("Upload completed.")
	print("Result: ", result)
	print("HTTP Code: ", response_code)
	print("Response:")
	print(body.get_string_from_utf8())
