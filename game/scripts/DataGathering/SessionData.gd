extends Node
class_name SessionData

var session: Dictionary = {}

func _ready() -> void:
	start_session()

func start_session() -> void:

	session = {

		"$id": str(Time.get_unix_time_from_system()),

		"info": {
			"name": "Open Saber Session",
			"timestamp": Time.get_unix_time_from_system()
		},

		"hardware": {
			"devices": [
				{
					"id": "headset",
					"name": "XR Headset"
				},
				{
					"id": "left_controller",
					"name": "Left Controller"
				},
				{
					"id": "right_controller",
					"name": "Right Controller"
				}
			]
		},

		"software": {
			"api": "OpenXR",
			"runtime": "",
			"app": {
				"id": "opensaber",
				"name": "Open Saber",
				"version": ProjectSettings.get_setting("application/config/version")
			},
			"extensions": []
		},

		"environment": {
			"id": "",
			"name": ""
		},

		"activity": {
			"id": "",
			"name": ""
		},

		"user": {
			"id": "",
			"name": ""
		}
	}

	print("Session metadata created.")
	print(session)

func set_user(user_id: String, username: String) -> void:
	if session.is_empty():
		start_session()
	session["user"] = {
		"id": user_id,
		"name": username
	}
	print("Session user set: ", session["user"])


func get_session() -> Dictionary:
	return session
