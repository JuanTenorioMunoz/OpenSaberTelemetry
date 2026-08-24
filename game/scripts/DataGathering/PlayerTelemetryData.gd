extends Node
class_name PlayerTelemetryData

@export var sample_rate: float = 30.0

var next_sample: float = 0.0
var frames: Array[Dictionary] = []

@onready var game := get_parent() as BeepSaber_Game
@onready var xr_camera := game.get_node("XROrigin3D/XRCamera3D") as XRCamera3D

# ================================================
# En esta sección obtendremos el song player para
# solamnente registrar los tiempos del evento de
# telemetría en función de la canción.
# ================================================
var _song_player: AudioStreamPlayer = null

func set_song_player(player: AudioStreamPlayer) -> void:
	_song_player = player
	next_sample = 0.0   # reset cadence at song start

func _song_time() -> float:
	if _song_player != null and is_instance_valid(_song_player):
		return _song_player.get_playback_position()
	return 0.0
# ==============================================

func _is_recording() -> bool:
	# Flag nuevo para decidir que momento grabar y que momentos no
	return _song_player != null and is_instance_valid(_song_player) and _song_player.playing

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
	if not _is_recording():
		return
	var t := _song_time()
	if t < next_sample:
		return
	next_sample = t + (1.0 / sample_rate)
	record_frame(t)

func record_frame(t: float) -> void:
	var frame := {
		"time": t,
		"headset": snapshot(xr_camera),
		"left_controller": snapshot(game.left_controller),
		"right_controller": snapshot(game.right_controller)
	}
	frames.append(frame)

func snapshot(node: Node3D) -> Dictionary:
	var pos := node.global_position
	var rot := node.global_basis.get_rotation_quaternion()
	return {
		"position": [pos.x, pos.y, pos.z],
		"rotation": [rot.x, rot.y, rot.z, rot.w],
	}
