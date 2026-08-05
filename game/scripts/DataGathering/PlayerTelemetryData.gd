extends Node
class_name PlayerTelemetryData

@export var sample_rate: float = 30.0

var next_sample: float = 0.0
var frames: Array[Dictionary] = []

@onready var game := get_parent() as BeepSaber_Game
@onready var xr_camera := game.get_node("XROrigin3D/XRCamera3D") as XRCamera3D

func _ready() -> void:
	print("=== PlayerTelemetryData initialized ===")

	if game == null:
		print("ERROR: Could not find BeepSaber_Game!")
		return

	print("Game: ", game)
	print("Camera: ", xr_camera)
	print("Left Controller: ", game.left_controller)
	print("Right Controller: ", game.right_controller)

func _process(_delta: float) -> void:
	var current_time := Time.get_ticks_msec() / 1000.0

	if current_time < next_sample:
		return

	next_sample = current_time + (1.0 / sample_rate)

	record_frame()

func record_frame() -> void:

	var frame := {
		"time": Time.get_ticks_msec() / 1000.0,
		"headset": snapshot(xr_camera),
		"left_controller": snapshot(game.left_controller),
		"right_controller": snapshot(game.right_controller)
	}

	frames.append(frame)

	print("----------------------------")
	print("Recorded frame #", frames.size())
	print("Time: ", frame["time"])
	print("Headset Position: ", frame["headset"]["position"])
	print("Left Controller Position: ", frame["left_controller"]["position"])
	print("Right Controller Position: ", frame["right_controller"]["position"])

func snapshot(node: Node3D) -> Dictionary:
	return {
		"position": node.global_position,
		"rotation": node.global_basis.get_rotation_quaternion()
	}
