extends Node

var url: String
var anon_key: String
var bucket: String
var folder: String

func _ready() -> void:
	var config := ConfigFile.new()

	var err := config.load("res://config/config.cfg")

	if err != OK:
		push_error("Couldn't load config.cfg")
		return

	url = config.get_value("supabase", "url")
	anon_key = config.get_value("supabase", "anon_key")
	bucket = config.get_value("supabase", "bucket")
	folder = config.get_value("supabase", "folder")

	print("Config loaded!")
	print(url)
	print(bucket)
