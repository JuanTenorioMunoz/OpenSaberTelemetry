extends Node
class_name SaberTelemetry

enum EventType {
	HIT_CORRECT,
	HIT_INCORRECT,
	MISSED
}

var events: Array[Dictionary] = []

# ================================================
# En esta sección obtendremos el song player para
# solamnente registrar los tiempos del evento de
# telemetría en función de la canción.
# ================================================
var _song_player: AudioStreamPlayer = null

func set_song_player(player: AudioStreamPlayer) -> void:
	_song_player = player

func _song_time() -> float:
	# Graceful fallback: if no song is active, time is 0.0 rather than a crash.
	if _song_player != null and is_instance_valid(_song_player):
		return _song_player.get_playback_position()
	return 0.0
# ================================================

func record_hit(
	controller: int,
	event_type: EventType,
	point: Vector3,
	normal: Vector3,
	direction: Vector3,
	strength: float,
	alignment: float,
	note_id: int,
	spawn_time: float,
	cut_distance_to_center: float,
	beat_accuracy: float,
	cut_angle_accuracy: float
) -> void:
	events.append({
		"time": _song_time(),
		"controller": controller,
		"type": event_type,
		"point": [point.x, point.y, point.z],
		"normal": [normal.x, normal.y, normal.z],
		"direction": [direction.x, direction.y, direction.z],
		"strength": strength,
		"alignment": alignment,
		"note_id": note_id,
		"spawn_time": spawn_time,
		"cut_distance_to_center": cut_distance_to_center,
		"beat_accuracy": beat_accuracy,
		"cut_angle_accuracy": cut_angle_accuracy,
	})
